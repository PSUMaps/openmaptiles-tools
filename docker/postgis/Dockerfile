ARG BASE_POSTGIS_VER=16-3.4
FROM postgis/postgis:$BASE_POSTGIS_VER

LABEL maintainer="Yuri Astrakhan <YuriAstrakhan@gmail.com>"

# https://github.com/libgeos/geos/releases
#ARG GEOS_VER=3.9.3

# https://github.com/pramsey/pgsql-gzip/releases
ARG PGSQL_GZIP_TAG=v1.0.0
ARG PGSQL_GZIP_REPO=https://github.com/pramsey/pgsql-gzip.git

# https://github.com/JuliaLang/utf8proc/releases
ARG UTF8PROC_TAG=v2.5.0
ARG UTF8PROC_REPO=https://github.com/JuliaLang/utf8proc.git

# https://github.com/pgRouting/pgrouting/releases
ARG PGROUTING_TAG=v3.6.2
ARG PGROUTING_REPO=https://github.com/pgRouting/pgrouting.git


RUN set -eux  ;\
    apt-get -qq -y update  ;\
    ##
    ## Install build dependencies
    apt-get -qq -y --no-install-recommends install \
        build-essential \
        cmake \
        ca-certificates \
        # Required by Nominatim to download data files
        curl \
        git \
        pandoc \
        # $PG_MAJOR is declared in postgres docker
        postgresql-server-dev-$PG_MAJOR \
        libkakasi2-dev \
        libgdal-dev \
    ;\
    ## Install specific GEOS version
    #cd /opt/  ;\
    #curl -o /opt/geos.tar.bz2 http://download.osgeo.org/geos/geos-${GEOS_VER}.tar.bz2  ;\
    #mkdir /opt/geos  ;\
    #tar xf /opt/geos.tar.bz2 -C /opt/geos --strip-components=1  ;\
    #cd /opt/geos/  ;\
    #./configure  ;\
    #make -j  ;\
    #make install  ;\
    #rm -rf /opt/geos*  ;\
    ##
    ## gzip extension
    cd /opt/  ;\
    git clone --quiet --depth 1 -b $PGSQL_GZIP_TAG $PGSQL_GZIP_REPO  ;\
    cd pgsql-gzip  ;\
    ln -s /usr/bin/clang-13 /usr/bin/clang-11  ;\
    ln -s /usr/lib/llvm-13 /usr/lib/llvm-11  ;\
    make  ;\
    make install  ;\
    rm -rf /opt/pgsql-gzip  ;\
    ##
    ## UTF8Proc
    cd /opt/  ;\
    git clone --quiet --depth 1 -b $UTF8PROC_TAG $UTF8PROC_REPO  ;\
    cd utf8proc  ;\
    make  ;\
    make install  ;\
    ldconfig  ;\
    rm -rf /opt/utf8proc  ;\
    ##
    ## pgrouting ext
    cd /opt/  ;\
    git clone --quiet --depth 1 -b $PGROUTING_TAG $PGROUTING_REPO  ;\
    cd pgrouting  ;\
    mkdir build ;\
    cd build ;\
    cmake  .. ;\
    make ;\
    make install  ;\
    rm -rf /opt/pgrouting  ;\
    ##
    ## Cleanup
    apt-get -qq -y --auto-remove purge \
        autoconf \
        automake \
        autotools-dev \
        build-essential \
        ca-certificates \
        bison \
        cmake \
        curl \
        dblatex \
        docbook-mathml \
        docbook-xsl \
        git \
        libcunit1-dev \
        libtool \
        make \
        g++ \
        gcc \
        pandoc \
        unzip \
        xsltproc \
        libpq-dev \
        postgresql-server-dev-$PG_MAJOR \
        libxml2-dev \
        libjson-c-dev \
        libgdal-dev \
    ;\
    rm -rf /usr/local/lib/*.a  ;\
    rm -rf /var/lib/apt/lists/*

# The script should run after the parent's 10_postgis.sh runs
# so it must have the name that's listed after that.
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/20_omt_postgis.sh
