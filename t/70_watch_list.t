use File::Spec;
use Test::More;
use Test::Fatal qw(lives_ok);

use Net::ZooKeeper qw(:all);

my $test_dir;
(undef, $test_dir, undef) = File::Spec->splitpath($0);
require File::Spec->catfile($test_dir, 'util.pl');

my($hosts, $root_path, $node_path) = zk_test_setup(0);

my $zkh = Net::ZooKeeper->new($hosts);
plan skip_all => "Could not connect to Net::ZooKeeper" unless defined $zkh;

my @watches = map {$zkh->watch(timeout => 1)} 0 .. 3;
my @paths   = map {"${node_path}_$i"}         0 .. 3;

# create linked list
$zkh->exists($paths[$_], watch => $watches[$_]) for 0 .. 2;
# set middle as done
$zkh->create($paths[1], "TESTING", acl => ZOO_OPEN_ACL_UNSAFE);
$watches[1]->wait(timeout => 1);
# cleanup middle
$zkh->exists($paths[3], watch => $watches[3]);

# cleanup the rest
for my $i (0 .. 2) {
    $zkh->create($paths[$i], "TESTING", acl => ZOO_OPEN_ACL_UNSAFE);
    $watches[$i]->wait(timeout => 1);
    $watches[$i] = undef;
}

lives_ok {
    $zkh->exists($paths[3], watch => $watches[3]);
    $zkh->exists($paths[3], watch => $watches[3]);
} "can add watches after messing with removing middle watch";

$zkh->delete($paths[$_]) for 0 .. 3;

done_testing;
