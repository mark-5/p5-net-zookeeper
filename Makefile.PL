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
use 5.008_008;

use Config;
use ExtUtils::MakeMaker;
use Getopt::Long;

my $ZOO_MAJOR_VERSION = 3;
my $ZOO_REQUIRED_VERSION = qr{^$ZOO_MAJOR_VERSION\.\d+.\d+$}ismx;

my @zk_inc_paths;
my @zk_lib_paths;

GetOptions(
    'zookeeper-include=s' => \@zk_inc_paths,
    'zookeeper-lib=s' => \@zk_lib_paths
);

my $zk_inc_paths = join(' ', map("-I$_", @zk_inc_paths));
my $zk_lib_paths = join(' ', map("-L$_", @zk_lib_paths));

$zk_inc_paths .= ' ' unless ($zk_inc_paths eq '');
$zk_lib_paths .= ' ' unless ($zk_lib_paths eq '');


my $lddlflags = $Config{'lddlflags'};
eval {
    require Alien::libzookeeper;
    $zk_inc_paths   .= ' ' . Alien::libzookeeper->cflags;
    my $libs         = Alien::libzookeeper->libs;
    my $libs_static  = Alien::libzookeeper->libs_static;
    if ( $libs ne $libs_static ) {
        # We can statically link against libzookeeper -- this likely means that
        # we are compiling against a private version built by Alien::libzookeeper.
        # To link statically, we need to pass arguments to `ld`, not to the C
        # compiler, and we need to drop the dynamic version:
        $_ =~ s/-lzookeeper(?:_mt)?\b// for $libs, $libs_static;
        $lddlflags  .= ' ' . $libs_static;
    }
    $zk_lib_paths   .= ' ' . $libs;
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

    my $check_out = qx($cc $zk_inc_paths $zk_lib_paths $extra_zk_lib -I. -o $check_file $check_file.c 2>&1);

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
            push @errors, "Net::ZooKeeper requires at least ZooKeeper version 3.2.0: $check_out\n";
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

    # libzookeeper is usable!  Update $zk_lib_paths if needed, and carry on:
    $zk_lib_paths .= ' ' . $extra_zk_lib;
    @errors        = ();
    last;
}

if ( @errors ) {
    die join "\n", @errors;
}

WriteMakefile(
    'INC'          => "$zk_inc_paths -I.",
    'LIBS'         => $zk_lib_paths,
    'LDDLFLAGS'    => $lddlflags,
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
                    'Alien::libzookeeper' => '0.02',
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

