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

use File::Spec;
use Test::More tests => 6;

BEGIN { use_ok('Net::ZooKeeper', qw(:all)) };


my $test_dir;
(undef, $test_dir, undef) = File::Spec->splitpath($0);
require File::Spec->catfile($test_dir, 'util.pl');

my($hosts, $root_path, $node_path) = zk_test_setup(0);


my $zkh = Net::ZooKeeper->new($hosts);
my $path;

SKIP: {
    my $ret = $zkh->exists($root_path) if (defined($zkh));

    skip 'no connection to ZooKeeper', 5 unless
        (defined($ret) and $ret);

    $path = $zkh->create($node_path, undef, 'acl' => ZOO_OPEN_ACL_UNSAFE);
    is($path, $node_path,
       'create(): created null node');

    my $data = $zkh->get($node_path);
    is($data, undef,
       'get(): null node returned undef');

    $ret = $zkh->set($node_path, undef);
    ok($ret,
       'set(): set null node');

    $data = $zkh->get($node_path);
    is($data, undef,
       'get(): null node returned undef');

    $ret = $zkh->delete($node_path);
    ok($ret,
       'delete(): deleted null node');
}

