#!/bin/bash

set -o verbose

# deps
sudo apt-get -y install libblocksruntime-dev libkqueue-dev libpthread-workqueue-dev cmake
sudo apt-get -y install libxml2-dev libxslt1-dev libffi-dev libssl-dev libgnutls-dev libicu-dev libgmp3-dev
sudo apt-get -y install libjpeg-dev libtiff-dev libpng-dev libgif-dev libx11-dev libcairo2-dev libxft-dev libxmu-dev 
sudo apt-get -y install libsqlite3-dev

# repos
git clone https://github.com/nickhutchinson/libdispatch && git checkout bd1808980b04830cbbd79c959b8bc554085e38a1 && git clean -dfx
git clone https://github.com/gnustep/libobjc2  && git checkout tags/v1.8.1 && git clean -dfx
# 2.6.8 breaks --disable-mixedabi by omitting -fobjc-nonfragile-abi among the compiler flags
wget ftp://ftp.gnustep.org/pub/gnustep/core/gnustep-make-2.6.7.tar.gz -O make.tar.gz && tar -xf make.tar.gz
wget ftp://ftp.gnustep.org/pub/gnustep/core/gnustep-base-1.24.9.tar.gz -O base.tar.gz && tar -xf base.tar.gz
git clone https://github.com/etoile/UnitKit && git clean -dfx

# libdispatch
cd libdispatch
mkdir build && cd build
../configure && make && sudo make install || exit 1
cd ../..

# libobjc2
cd libobjc2
mkdir build && cd build
cmake .. && make -j8 && sudo make install || exit 1
cd ../..

# gnustep make
cd make
./configure --enable-debug-by-default --enable-objc-nonfragile-abi --enable-objc-arc && make && sudo make install || exit 1
cd ..
source /usr/local/share/GNUstep/Makefiles/GNUstep.sh || exit 1

# gnustep base
cd base
./configure --disable-mixedabi && make -j8 && sudo make install || exit 1
cd ..

# UnitKit
cd UnitKit
wget https://raw.githubusercontent.com/etoile/Etoile/master/etoile.make
make -j8 && sudo make install || exit 1
make test=yes && ukrun -q TestSource/TestUnitKit/TestUnitKit.bundle || exit 1
cd ..
