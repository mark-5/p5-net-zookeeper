use Test::More;
use strict;
use warnings;
BEGIN { use_ok('Net::ZooKeeper', qw(:all)) };

ok(defined ZOO_EPHEMERAL, "ZOO_EPHEMERAL");
ok(defined ZOO_SEQUENCE, "ZOO_SEQUENCE");

ok(defined ZOO_PERM_READ, "ZOO_PERM_READ");
ok(defined ZOO_PERM_WRITE, "ZOO_PERM_WRITE");
ok(defined ZOO_PERM_CREATE, "ZOO_PERM_CREATE");
ok(defined ZOO_PERM_DELETE, "ZOO_PERM_DELETE");
ok(defined ZOO_PERM_ADMIN, "ZOO_PERM_ADMIN");
ok(defined ZOO_PERM_ALL, "ZOO_PERM_ALL");

ok(defined ZOO_OPEN_ACL_UNSAFE, "ZOO_OPEN_ACL_UNSAFE");
ok(defined ZOO_READ_ACL_UNSAFE, "ZOO_READ_ACL_UNSAFE");
ok(defined ZOO_CREATOR_ALL_ACL, "ZOO_CREATOR_ALL_ACL");

ok(defined ZOO_LOG_LEVEL_OFF, "ZOO_LOG_LEVEL_OFF");
ok(defined ZOO_LOG_LEVEL_ERROR, "ZOO_LOG_LEVEL_ERROR");
ok(defined ZOO_LOG_LEVEL_WARN, "ZOO_LOG_LEVEL_WARN");
ok(defined ZOO_LOG_LEVEL_INFO, "ZOO_LOG_LEVEL_INFO");
ok(defined ZOO_LOG_LEVEL_DEBUG, "ZOO_LOG_LEVEL_DEBUG");

done_testing;
