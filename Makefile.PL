# Net::ZooKeeper - Perl extension for Apache ZooKeeper
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use v5.15;

use Config;
use ExtUtils::MakeMaker;
use Text::ParseWords qw(shellwords);
use Getopt::Long;

sub prepare_lddlflags {
    my ($lddlflags) = @_;
    # `-Wl,-z,now` breaks static linking to libmariadbclient.a, and
    # the perl you get from pacman in ArchLinux has that by default
    # in lddlflags.
    $lddlflags =~ s<,-z[,= ]now><>g;
    $lddlflags =~ s<,--as-needed\b><>g;
    $lddlflags =~ s<-Wl\s>< >g; # did we remove every linker option?
    return $lddlflags;
}

my $ZOO_MAJOR_VERSION = 3;
my $ZOO_REQUIRED_VERSION = qr{^$ZOO_MAJOR_VERSION\.\d+.\d+$}ismx;

my @zk_inc_paths;
my @zk_lib_paths;

GetOptions(
    'zookeeper-include=s' => \@zk_inc_paths,
    'zookeeper-lib=s' => \@zk_lib_paths
);

my @archive_after;
my $makemaker_libs = [];
my $makemaker_inc  = join(' ', map("-I$_", @zk_inc_paths));

my $ccflags    = $Config{'ccflags'} // '';
my $cccdlflags = $Config{'cccdlflags'} // ''; # -fPIC
my $lddlflags  = prepare_lddlflags($Config{'lddlflags'} // '');

$lddlflags .= ' ' . join ' ', @zk_lib_paths;

eval {
    require Alien::libzookeeper;
    $makemaker_inc .= ' ' . Alien::libzookeeper->cflags;
    my $libs = Alien::libzookeeper->install_type eq 'share'
         ? Alien::libzookeeper->libs_static || Alien::libzookeeper->libs
         : Alien::libzookeeper->libs
    ;
    # cmake/OSX bug: -lz gets transformed into
    #   -l/abs/path/to/libz.tbd
    # in systems with Apple's "built-in dynamic linker cache"
    $libs =~ s<\B-l/></>g;

    my $lib_ext = $Config{lib_ext};
    foreach my $maybe_lib ( shellwords($libs) ) {
        if ( $maybe_lib =~ m/\B-l(\S+)/ ) {
            # -lfoo
            push @$makemaker_libs, $maybe_lib;
        }
        elsif ( $maybe_lib =~ m<-L(\S+)> ) {
            my $lib_dir = $1;
            # /path/to/libs
            # add '-Wl,-rpath=$dir'
            $libs = '-Wl,-rpath,' . $lib_dir . ' ' . $libs;
        }
        elsif ( $maybe_lib =~ m<^/.+$lib_ext$> ) {
            # .a file in pkg-config --libs output -- this needs to come after the -o
            push @archive_after, $maybe_lib;
        }
    }

    $lddlflags .= ' ' . $libs;
    1;
} or do {
    my $e = $@ || '';
    # ignore errors from Alien::libzookeeper.  nice if it's available,
    # but not required.
};

my @errors;
my $check_file = 'build/check_zk_version';
foreach my $extra_zk_lib ( '', '-lzookeeper', '-lzookeeper_mt' ) {
    my $cc = $Config{'cc'};

    my $cmd = "$cc $makemaker_inc $lddlflags $cccdlflags $extra_zk_lib -I. -o $check_file $check_file.c 2>&1";
    my $check_out = qx($cmd);

    my $compile_status    = $?;
    my $compile_exit_code = $compile_status >> 8;
    if ( $compile_exit_code != 0 ) {
        # It failed -- save the output and status code, we will use them
        # if all tries fail:
        if ($check_out =~ /zookeeper_version\.h/) {
            push @errors, "Could not determine ZooKeeper version:\n\n$check_out";
        }
        else {
            ## keep in sync with build/check_zk_version.h
            push @errors, "Net::ZooKeeper requires at least ZooKeeper version 3.2.0:\n$cmd\n$check_out\n";
        }
        next;
    }

    chomp(my $zk_ver = qx($check_file));

    my $exit_code = $? >> 8;
    if ($exit_code != 0) {
        push @errors, "Couldn't check zookeeper version: $zk_ver: $exit_code";
    }
    elsif ($zk_ver !~ $ZOO_REQUIRED_VERSION) {
        # TODO: should we try other alternatives here?
        warn "Net::ZooKeeper requires ZooKeeper 3.x, found $zk_ver!";
    }

    # libzookeeper is usable!  Update $lddlflags if needed, and carry on:
    $lddlflags .= ' ' . $extra_zk_lib;
    @errors        = ();
    last;
}

if ( @errors ) {
    die join "\n", @errors;
}

WriteMakefile(
    'INC'          => "$makemaker_inc -I.",
    'LIBS'         => $makemaker_libs,
    'LDDLFLAGS'    => $lddlflags,
    'CCFLAGS'      => $ccflags,
    'PERL_ARCHIVE_AFTER' => join(' ', @archive_after),
    'NAME'         => 'Net::ZooKeeper',
    'VERSION_FROM' => 'ZooKeeper.pm',
    'clean'        => { 'FILES' => 'build/check_zk_version.o' },
    'META_MERGE'   => {
        'meta-spec' => { version => 2 },
        prereqs => {
            test => {
                requires => {
                    version => '0.77',
                },
            },
            configure => {
                # optionally use Alien::libzookeeper, but not a hard requirement:
                recommends => {
                    'Alien::libzookeeper' => '0.03',
                },
            },
        },
        resources => {
            homepage   => "https://github.com/mark-5/p5-net-zookeeper",
            bugtracker => {
                web => "https://github.com/mark-5/p5-net-zookeeper/issues",
            },
            repository => {
                web  => "https://github.com/mark-5/p5-net-zookeeper",
                url  => "https://github.com/mark-5/p5-net-zookeeper.git",
                type => 'git',
            },
        },
    },
);

