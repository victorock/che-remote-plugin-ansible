# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: GPLv-3.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
ARG CHE_RUNTIME_VERSION 7.0.0-next
FROM eclipse/che-theia-endpoint-runtime:${CHE_RUNTIME_VERSION}

# PYTHON VERSION
ENV PYTHON_VERSION 3.7.3
# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 19.2.2

# ANSIBLE VERSION
ENV ANSIBLE_VERSION 2.8.3

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# install ca-certificates so that HTTPS works consistently
# other runtime dependencies for Python are installed later
RUN apk add --no-cache ca-certificates

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D

RUN set -ex \
	&& apk add --update --no-cache --virtual .fetch-deps \
		gnupg \
		tar \
		xz \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& apk add --update --no-cache --virtual .build-deps  \
		bzip2 \
    bzip2-dev \
		coreutils \
    curl \
    curl-dev \
		dpkg-dev dpkg \
		expat-dev \
		findutils \
		gcc \
    gettext \
    g++ \
		gdbm-dev \
		libc-dev \
    libcurl \
		libffi-dev \
		libnsl-dev \
		libtirpc-dev \
    libxslt \
    libxslt-dev \
    libxml2 \
    libxml2-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
    sudo \
		tcl-dev \
		tk \
		tk-dev \
		util-linux-dev \
		xz-dev \
		zlib-dev \
# add build deps before removing fetch deps in case there's overlap
	&& apk del .fetch-deps \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-shared \
		--with-system-expat \
		--with-system-ffi \
		--without-ensurepip \
	&& make -j "$(nproc)" \
# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
		EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000" \
	&& make install \
	\
	&& find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		| xargs -rt apk add --no-cache --virtual .python-rundeps \
	&& apk add --no-cache --virtual .python-rundeps \
		ctags \
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python \
	\
	&& python3 --version

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config

RUN set -ex; \
  umask 0022; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version \
	; \
	sudo pip install --upgrade pip && \
    sudo pip install --no-cache-dir virtualenv && \
    sudo pip install --upgrade setuptools \
	; \	
	pip install pylint python-language-server[all] \
    "ansible==${ANSIBLE_VERSION}" \
    pyinotify \
    apache-libcloud \
    google-cloud \
    azure \
    boto \
    boto3 \
    ovirt-engine-sdk-python \
    pyvmomi \
    netaddr \
    requests \
    "idna<2.8" \
    ansible-tower-cli \
    "pexpect==4.6.0" \
    python-memcached \
    molecule \
    xmltodict \
    ncclient \
    f5-sdk \
    f5-icontrol-rest \
    passlib \
    pandevice \
    pan-python \
    avisdk \
    ansible-review \
    infoblox-client \
    jmespath \
    yaql \
    "click==6.7" \
    "colorama==0.3.9" \
    "Jinja2==2.10" \
    "PyYAML==3.13" \
    "six==1.11.0" \
  ; \
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py \
	; \
	apk del .build-deps
