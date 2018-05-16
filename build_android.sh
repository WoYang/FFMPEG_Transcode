#!/bin/bash

#Detect ANDROID_NDK
export ANDROID_NDK=/home3/yangwu/build_tools/android-ndk-r14b

NDK_TOOLCHAIN_VERSION=4.9
ANDROID_PLATFROM_VERSION=android-19

if [ -z "$ANDROID_NDK" ]; then
 echo "You must define ANDROID_NDK before starting."
 echo "You must point to your NDK directories.\n"
 exit 1
fi

#Detect OS
OS=`uname`
HOST_ARCH=`uname -m`
export CCACHE=; type ccache >/dev/null 2>&1 && export CCACHE=ccache
if [ $OS == 'Linux' ]; then
 export HOST_SYSTEM=linux-$HOST_ARCH
elif [ $OS == 'Darwin' ]; then
 export HOST_SYSTEM=darwin-$HOST_ARCH
fi

platform="$1"
version_type="$2"

function arm_toolchain()
{
 export CROSS_PREFIX=arm-linux-androideabi-
 $ANDROID_NDK/build/tools/make-standalone-toolchain.sh --toolchain=${CROSS_PREFIX}${NDK_TOOLCHAIN_VERSION} --platform=${ANDROID_PLATFROM_VERSION} --install-dir=$TOOLCHAIN --arch=arm --force
  #--system=$HOST_SYSTEM #ndk4.9 do not support --system
}

function x86_toolchain()
{
 export CROSS_PREFIX=i686-linux-android-
 $ANDROID_NDK/build/tools/make-standalone-toolchain.sh --toolchain=x86-${NDK_TOOLCHAIN_VERSION} --platform=${ANDROID_PLATFROM_VERSION} --install-dir=$TOOLCHAIN --arch=x86 --force
  #--system=$HOST_SYSTEM #ndk4.9 do not support --system
}

function mips_toolchain()
{
 export CROSS_PREFIX=mipsel-linux-android-
 $ANDROID_NDK/build/tools/make-standalone-toolchain.sh --toolchain=${CROSS_PREFIX}${NDK_TOOLCHAIN_VERSION} --platform=${ANDROID_PLATFROM_VERSION} --install-dir=$TOOLCHAIN --arch=mips --force
  #--system=$HOST_SYSTEM #ndk4.9 do not support --system
}


SOURCE=`pwd`
DEST=$SOURCE/build/android
TOOLCHAIN=$SOURCE/ffmpeg_toolchain
SYSROOT=$TOOLCHAIN/sysroot/

function download {
  mkdir -p "$SOURCE/downloads"
  if [[ ! -e "$SOURCE/downloads/$2" ]]; then
    echo "Downloading $1"
    curl -L "$1" -o "$SOURCE/downloads/$2"
  fi
}

if [ "$platform" = "x86" ];then
 echo "Build Android x86 ffmpeg\n"
 x86_toolchain
 TARGET="x86"
 TARGET_HOST="x86-linux-android"
 PLATFORM="arch-x86"
elif [ "$platform" = "mips" ];then
 echo "Build Android mips ffmpeg\n"
 mips_toolchain
 TARGET="mips"
 TARGET_HOST="mipsel-linux-android"
 PLATFORM="arch-mips"
elif [ "$platform" = "armv7" ];then
 echo "Build Android armv7 ffmpeg\n"
 arm_toolchain
 TARGET="armv7"
 TARGET_HOST="armv7a-linux-androideabi"
 PLATFORM="arch-arm"
else
 echo "Build Android arm ffmpeg\n"
 arm_toolchain
 TARGET="neon armv7 vfp armv6"
 TARGET_HOST="arm-linux-android"
 PLATFORM="arch-arm"
fi
export PATH=$TOOLCHAIN/bin:$PATH
export CC="$CCACHE ${CROSS_PREFIX}gcc"
export CXX=${CROSS_PREFIX}g++
export LD=${CROSS_PREFIX}ld
export AR=${CROSS_PREFIX}ar
export STRIP=${CROSS_PREFIX}strip

#set ffmpeg dep libs here
echo "Decompressing archives..."
OPENH264_VERSION=1.6.0
FDKACC_VERSION=0.1.6
OPENSSL_VERSION=openssl-1.0.2j

download https://github.com/cisco/openh264/archive/v$OPENH264_VERSION.tar.gz openh264-$OPENH264_VERSION.tar.gz
download ftp://ftp.videolan.org/pub/videolan/x264/snapshots/last_stable_x264.tar.bz2 last_stable_x264.tar.bz2
#download https://downloads.sourceforge.net/opencore-amr/fdk-aac-$FDKACC_VERSION.tar.gz
download https://www.openssl.org/source/$OPENSSL_VERSION.tar.gz $OPENSSL_VERSION.tar.gz

tar --totals -xzf $SOURCE/downloads/openh264-$OPENH264_VERSION.tar.gz -C $SOURCE/downloads/
tar --totals -xjf $SOURCE/downloads/last_stable_x264.tar.bz2 -C $SOURCE/downloads/
tar --totals -xzf $SOURCE/downloads/fdk-aac-$FDKACC_VERSION.tar.gz -C $SOURCE/downloads/
tar --totals -xzf $SOURCE/downloads/$OPENSSL_VERSION.tar.gz -C $SOURCE/downloads/

X264=`echo $SOURCE/downloads/x264-snapshot-*`
FDKACC=`echo $SOURCE/downloads/fdk-aac-*`
OpenSSL=`echo $SOURCE/downloads/openssl-*`

CFLAGS="-std=c99 -O3 -Wall -pipe -fpic -fasm -finline-limit=300 -ffast-math -fstrict-aliasing -Wno-psabi -Wa,--noexecstack -fdiagnostics-color=always -DANDROID -DNDEBUG"
LDFLAGS="-lm -lz -Wl,--no-undefined -Wl,-z,noexecstack"

case $CROSS_PREFIX in
 arm-*)
  CFLAGS="-mthumb $CFLAGS -D__ARM_ARCH_5__ -D__ARM_ARCH_5E__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5TE__"
  ;;
 x86-*)
  ;;
 mipsel-*)
  CFLAGS="-std=c99 -O3 -Wall -pipe -fpic -fasm  -ftree-vectorize -ffunction-sections -funwind-tables -fomit-frame-pointer -funswitch-loops  -finline-limit=300 -finline-functions -fpredictive-commoning -fgcse-after-reload -fipa-cp-clone  -Wno-psabi -Wa,--noexecstack  -DANDROID -DNDEBUG"
  ;;
esac

if [ "$version_type" = "online" ]; then
 FFMPEG_FLAGS_COMMON="--target-os=android --cross-prefix=$CROSS_PREFIX --enable-cross-compile --enable-version3 --enable-shared --disable-static --disable-symver --disable-programs --disable-doc --disable-avdevice --disable-encoders  --disable-muxers --disable-devices --disable-everything --disable-protocols  --disable-demuxers --disable-decoders --disable-bsfs --disable-debug --enable-optimizations --enable-filters --enable-parsers --disable-parser=hevc --enable-swscale  --enable-network --enable-protocol=file --enable-protocol=http --enable-protocol=rtmp --enable-protocol=rtp --enable-protocol=mmst --enable-protocol=mmsh --enable-protocol=crypto --enable-protocol=hls --enable-demuxer=hls --enable-demuxer=mpegts --enable-demuxer=mpegtsraw --enable-demuxer=mpegvideo --enable-demuxer=concat --enable-demuxer=mov --enable-demuxer=flv --enable-demuxer=rtsp --enable-demuxer=mp3 --enable-demuxer=matroska --enable-decoder=mpeg4 --enable-decoder=mpegvideo --enable-decoder=mpeg1video --enable-decoder=mpeg2video --enable-decoder=h264 --enable-decoder=h263 --enable-decoder=flv --enable-decoder=vp8 --enable-decoder=wmv3 --enable-decoder=aac --enable-decoder=ac3 --enable-decoder=mp3 --enable-decoder=nellymoser --enable-muxer=mp4 --enable-asm --enable-pic"
else
 FFMPEG_FLAGS_COMMON="--target-os=android --cross-prefix=$CROSS_PREFIX --enable-cross-compile --enable-version3 --enable-shared --disable-static --disable-symver --disable-programs --disable-doc --disable-avdevice --disable-encoders --enable-libx264 --enable-gpl --enable-nonfree --enable-encoder=libx264 --enable-encoder=aac --enable-encoder=mp2 --disable-muxers --enable-muxer=mp4 --enable-muxer=mpegts --enable-muxer=rtp --enable-muxer=rtp_mpegts --disable-devices --disable-demuxer=sbg --disable-demuxer=dts --disable-parser=dca --disable-decoder=dca --disable-decoder=svq3 --enable-optimizations --disable-fast-unaligned --disable-postproc --enable-network --enable-asm --enable-openssl --disable-debug --enable-pthread"
fi

 for version in $TARGET; do

  cd $SOURCE

  FFMPEG_FLAGS="$FFMPEG_FLAGS_COMMON"

  case $version in
   neon)
    FFMPEG_FLAGS="--arch=armv7-a --cpu=cortex-a8 --disable-runtime-cpudetect $FFMPEG_FLAGS"
    EXTRA_CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=softfp -mvectorize-with-neon-quad"
    EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
    SSL_OBJS=""
    ;;
   armv7)
    FFMPEG_FLAGS="--arch=armv7-a --cpu=cortex-a8 --disable-runtime-cpudetect $FFMPEG_FLAGS"
    EXTRA_CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"
    EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
    SSL_OBJS=""
    ;;
   vfp)
    FFMPEG_FLAGS="--arch=arm --disable-runtime-cpudetect $FFMPEG_FLAGS"
    EXTRA_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=softfp"
    EXTRA_LDFLAGS=""
    SSL_OBJS=""
    ;;
   armv6)
    FFMPEG_FLAGS="--arch=arm --disable-runtime-cpudetect $FFMPEG_FLAGS"
    EXTRA_CFLAGS="-march=armv6 -msoft-float"
    EXTRA_LDFLAGS=""
    SSL_OBJS=""
    ;;
   x86)
    FFMPEG_FLAGS="--arch=x86 --cpu=i686 --enable-runtime-cpudetect --enable-yasm --disable-amd3dnow --disable-amd3dnowext $FFMPEG_FLAGS"
    EXTRA_CFLAGS="-march=atom -msse3 -ffast-math -mfpmath=sse"
    EXTRA_LDFLAGS=""
    SSL_OBJS=""
    ;;
   mips)
    FFMPEG_FLAGS="--arch=mips --cpu=mips32r2 --enable-runtime-cpudetect --enable-yasm --disable-mipsfpu --disable-mipsdspr1 --disable-mipsdspr2 $FFMPEG_FLAGS"
    EXTRA_CFLAGS="-fno-strict-aliasing -fmessage-length=0 -fno-inline-functions-called-once -frerun-cse-after-loop -frename-registers"
    EXTRA_LDFLAGS=""
    SSL_OBJS=""
    ;;
   *)
    FFMPEG_FLAGS=""
    EXTRA_CFLAGS=""
    EXTRA_LDFLAGS=""
    SSL_OBJS=""
    ;;
  esac

  PREFIX="$DEST/$version" && rm -rf $PREFIX && mkdir -p $PREFIX
  FFMPEG_FLAGS="$FFMPEG_FLAGS --prefix=$PREFIX"

 #build OpenSSL	 
	cd $OpenSSL
    ./Configure --prefix=$PREFIX android-$TARGET $CFLAGS $EXTRA_CFLAGS no-shared 
	[ $PIPESTATUS == 0 ] || exit 1
	make -j12 || exit 1
	make install
	
# build X264	
	cd $X264
	./configure --prefix=$PREFIX --enable-static --enable-pic --disable-cli --cross-prefix=$CROSS_PREFIX --sysroot=$SYSROOT --host=$TARGET_HOST --extra-cflags="$CFLAGS $EXTRA_CFLAGS" --extra-ldflags="$LDFLAGS $EXTRA_LDFLAGS"
	[ $PIPESTATUS == 0 ] || exit 1
	make -j12 || exit 1
	make install
	
# build FDKACC
#	cd $FDKACC
#	./configure --prefix=$PREFIX --with-sysroot=$ANDROID_NDK/platforms/$ANDROID_PLATFROM_VERSION/$PLATFORM --host=$TARGET_HOST
#	[ $PIPESTATUS == 0 ] || exit 1
#	make -j12 || exit 1
#	make install	
	
# build ffmpeg	
	cd $SOURCE
	./configure $FFMPEG_FLAGS --extra-cflags="$CFLAGS $EXTRA_CFLAGS -I$DEST/$TARGET/include" --extra-ldflags="$LDFLAGS $EXTRA_LDFLAGS -L$DEST/$TARGET/lib" | tee $PREFIX/configuration.txt
	cp config.* $PREFIX
	[ $PIPESTATUS == 0 ] || exit 1

	make clean
	find . -path $TOOLCHAIN -prune -name "*.o" -type f -delete
	make -j12 || exit 1
		
	make examples

	make install
  echo "----------------------$version -----------------------------"
	
 done 