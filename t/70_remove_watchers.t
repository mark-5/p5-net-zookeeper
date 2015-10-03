use strict;
use warnings;
use File::Spec;
use Test::More;

BEGIN { use_ok('Net::ZooKeeper', qw(:all)) };


my $test_dir;
(undef, $test_dir, undef) = File::Spec->splitpath($0);
require File::Spec->catfile($test_dir, 'util.pl');

my($hosts, $root_path, $node_path) = zk_test_setup(0);
$node_path .= "-$$";

my $zkh = Net::ZooKeeper->new($hosts);

{
    my $triggered = $zkh->watch;
    $zkh->exists($node_path, watch => $triggered);
    $zkh->create($node_path, '',
                 flags => ZOO_EPHEMERAL,
                 acl   => ZOO_OPEN_ACL_UNSAFE);

    ok $triggered->wait(timeout => 1), 'triggered normal exists watch';
}

{
    my $removed = $zkh->watch;
    $zkh->exists($node_path, watch => $removed);
    $zkh->remove_watchers($node_path);
    $zkh->delete($node_path);
    ok not($removed->wait(timeout => 1)), 'did not trigger exists watch after removing all watchers';
}

{
    my $triggered = $zkh->watch;
    my $removed   = $zkh->watch;
    $zkh->exists($node_path, watch => $_) for $triggered, $removed;
    $zkh->remove_watchers($node_path, watch => $removed);

    $zkh->create($node_path, '',
                 flags => ZOO_EPHEMERAL,
                 acl   => ZOO_OPEN_ACL_UNSAFE);
    ok not($removed->wait(timeout => 1)), 'did not trigger watch after removing specific watch';
    ok $triggered->wait(timeout => 1), 'triggered other watcher after removing specific watch';
}

done_testing();
