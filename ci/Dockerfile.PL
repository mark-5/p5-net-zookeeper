#!/usr/bin/env perl
use strict;
use warnings;
use version 0.77;
use IO::File;
my $path = substr($0, 0, -3);

my @missing = grep { not exists $ENV{$_} } qw(
    ZOOKEEPER_VERSION
    PERL_VERSION
);
if (@missing) {
    my $msg = "Missing required env vars:\n";
    $msg   .= "  $_\n" for @missing;
    die "$msg\n";
}

my $perl_version      = $ENV{PERL_VERSION};
my $perl_flags        = $ENV{PERL_THREADS} ? '--thread' : '';
my $zookeeper_version = $ENV{ZOOKEEPER_VERSION};
(my $zookeeper_version_number = $zookeeper_version) =~ s/-.*$//;

my $zookeeper_archive;
if ( qv($zookeeper_version_number) >= qv(3.5.5) ) {
    $zookeeper_archive = "apache-zookeeper-$zookeeper_version";
} else {
    $zookeeper_archive = "zookeeper-$zookeeper_version";
}

my $zookeeper_bindings;
if ( qv($zookeeper_version_number) >= qv(3.4.14) ) {
    $zookeeper_bindings = "zookeeper-client/zookeeper-client-c";
} else {
    $zookeeper_bindings = "src/c";
}

my %build = (
    command  => 'true',
    cflags   => '',
    packages => [],
    plflags  => '',
);
if ( qv($zookeeper_version_number) >= qv(3.6.0) ) {
    # jute needs to be explicitly compiled for 3.6.0+
    $build{command}  = 'mvn -pl :zookeeper-jute -am clean compile';
    $build{packages} = [ 'maven' ];
} else {
    # fix for gcc 8 (ZOOKEEPER-3302) only in 3.6.0+
    $build{cflags} = sprintf(q{'CFLAGS=%s'}, join(' ', qw(
        -g -O2 -D_GNU_SOURCE
        -Wno-error=format-overflow
        -Wno-error=nonnull
        -Wno-error=stringop-truncation
    )));
}
if ( $ENV{SASL2} ) {
    $build{plflags} = '--with-sasl2';
    push @{ $build{packages} }, 'libsasl2-dev';
}

my @system_packages = qw(
    autoconf
    automake
    curl
    libcppunit-dev
    libssl-dev
    libtool
    make
    openjdk-11-jre
    perl
);
push @system_packages, @{ $build{packages} };

my $file = IO::File->new($path, 'w')
    or die "cannot open $path for writing: !";
print $file <<"__END__";

FROM debian:stable-20201012
RUN apt-get -q -y update \\
 && apt-get -q -y install @system_packages

RUN mkdir -p /opt \\
 && curl -L https://archive.apache.org/dist/zookeeper/zookeeper-$zookeeper_version/$zookeeper_archive.tar.gz | tar -C /opt -zxf - \\
 && ln -s /opt/$zookeeper_archive /opt/zookeeper \\
 && cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg \\
 && mkdir -p /tmp/zookeeper
EXPOSE 2181 2888 3888

RUN cd /opt/zookeeper \\
 && $build{command} \\
 && cd $zookeeper_bindings \\
 && echo 'AC_DEFUN([AM_PATH_CPPUNIT], [true])' >> acinclude.m4 \\
 && echo 'AC_DEFUN([CHECK_CPPUNIT], [true])' >> acinclude.m4 \\
 && autoreconf -if \\
 && ./configure \\
 && make install $build{cflags} \\
 && ldconfig

RUN test -d /usr/local/include/zookeeper \\
 || ln -s /usr/local/include/c-client-src /usr/local/include/zookeeper

COPY --from=perl:$perl_version /usr/local/bin/       /usr/local/bin/
COPY --from=perl:$perl_version /usr/local/lib/perl5/ /usr/local/lib/perl5/

WORKDIR /code
COPY . /code
RUN perl Makefile.PL $build{plflags} \\
 && cpanm --quiet --notest --with-develop --with-all-features --installdeps . \\
 && make

__END__
