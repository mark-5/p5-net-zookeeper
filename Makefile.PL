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

use 5.008_008;

use Config;
use ExtUtils::MakeMaker;
use Getopt::Long;
use Try::Tiny;
use version;

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


my %MM_ARGS = (
    'INC'           => "$zk_inc_paths-I.",
    'LIBS'          => [ "$zk_lib_paths-lzookeeper_mt" ],
    'NAME'          => 'Net::ZooKeeper',
    'VERSION_FROM'  => 'ZooKeeper.pm',
    'clean'         => { 'FILES' => 'build/check_zk_version.o' },
    'BUILD_REQUIRES'=> {
        'Test::Fatal' => 0,
    },
    'CONFIGURE_REQUIRES' => {
        'version'     => 0,
        'Try::Tiny'   => 0,
    },
    'META_MERGE'    => {
        'resources' => {
            'repository' => 'https://github.com/mark-5/p5-net-zookeeper.git',
        },
    },
);

my $version = try {
    return get_zookeeper_version();
} catch {
    my $original_error = $_;
    return try {
        # try including zookeeper/zookeeper_version.h
        my $zk_version = get_zookeeper_version(define => "-DUSE_ZOOKEEPER_SUBDIR");
        $MM_ARGS{DEFINE} = "-DUSE_ZOOKEEPER_SUBDIR";
        return $zk_version;
    } catch {
        die $original_error;
    };
};
die("Net::ZooKeeper requires at least ZooKeeper version 3.1.1. Found $version\n")
    unless is_required_version($version);


WriteMakefile(%MM_ARGS);


sub get_zookeeper_version {
    my (%args) = @_;
    my $check_file = "build/check_zk_version";
    my $define = $args{define} || "";
    my $check_out =
        qx($Config{'cc'} $define $zk_inc_paths $check_file.c -o $check_file 2>&1 && ./$check_file 2>&1);

    die("Could not determine ZooKeeper version:\n\n$check_out") if $?;
    return $check_out;
}

sub is_required_version {
    my ($version) = @_;
    return version->parse($version) >= version->parse('3.1.1');
}
