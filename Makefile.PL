use inc::Module::Install;
use Getopt::Long;

my @zk_inc_paths;
my @zk_lib_paths;
GetOptions(
    'zookeeper-include=s' => \@zk_inc_paths,
    'zookeeper-lib=s' => \@zk_lib_paths,
);
cc_include_paths @zk_inc_paths if @zk_inc_paths;
cc_libs map {"-L$_"} @zk_lib_paths if @zk_lib_paths;


my $version_check = q/
#if !defined(ZOO_MAJOR_VERSION) || ZOO_MAJOR_VERSION != 3 || \
    !defined(ZOO_MINOR_VERSION) || ZOO_MINOR_VERSION < 1 || \
    !defined(ZOO_PATCH_VERSION) || \
    (ZOO_MINOR_VERSION == 1 && ZOO_PATCH_VERSION < 1)
#error "Net::ZooKeeper requires at least ZooKeeper version 3.1.1"
#endif
return 0;
/;
if (eval {assertlibs(header => 'zookeeper/zookeeper.h', incpath => \@zk_inc_paths); 1}) {
    checklibs(header => 'zookeeper/zookeeper.h', function => $version_check, incpath => \@zk_inc_paths);
    cc_define '-DUSE_ZOOKEEPER_SUBDIR';
} else {
    checklibs(header => 'zookeeper.h', function => $version_check, incpath => \@zk_inc_paths);
}

use_ppport;
cc_src_paths 'src';
cc_libs '-lzookeeper_mt';

test_requires 'Test::Fatal';

author_requires 'Module::Install::AuthorRequires';
author_requires 'Module::Install::XSUtil';
author_requires 'Module::Install::CheckLib';
author_requires 'Module::Install::GithubMeta';

homepage 'https://github.com/mark-5/p5-net-zookeeper';
githubmeta;

name 'Net-ZooKeeper';
all_from 'lib/Net/ZooKeeper.pm';
WriteAll;
