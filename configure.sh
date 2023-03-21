#!/bin/bash
TOP="$(realpath .)"
export DEBFULLNAME="Maarten Fonville"
export DEBEMAIL="maarten.fonville@gmail.com"

for t in "wget" "xml2"; do
  if ! command -v $t >/dev/null 2>&1; then
    echo "$t is required but is not installed."; exit 1
  fi
done

d="$1"
case "$d" in
  focal|jammy|kinetic|lunar);;
  clean) rm build-tools_*.zip; exit 0;;
  *) echo "Unrecognized Ubuntu version, use a valid distribution as 1st argument"; exit 1;;
esac

for repv in $(seq 5 -1 1); do  # start at 5, that should be relatively safe for the near future, since we know the current protocol is on 3 (mar 2023)
  if wget -q --spider "https://dl.google.com/android/repository/repository2-$repv.xml"; then
    break
  fi
done
if [ "$repv" = "4" ]; then # we know 4 does not really exist and is an invalid result
  echo "Could not fetch Google's Android Tools XML repository"
  exit 1
fi

latest="$(wget -q -O - "https://dl.google.com/android/repository/repository2-$repv.xml" | xml2 | sed -n '\#^/sdk:sdk-repository/remotePackage/@path=build-tools;#,\#^/sdk:sdk-repository/remotePackage$#{p;\#^/sdk:sdk-repository/remotePackage$#q}')"
latest_linux="$(echo "$latest" | sed -e '\#sdk:sdk-repository/remotePackage/archives/archive/host-os=linux#,$d' | tail -n 5)" # assuming there are 5 lines for this result
latest_major="$(echo "$latest" | grep '/sdk:sdk-repository/remotePackage/revision/major=' | cut -d= -f 2-)"
latest_minor="$(echo "$latest" | grep '/sdk:sdk-repository/remotePackage/revision/minor=' | cut -d= -f 2-)"
latest_micro="$(echo "$latest" | grep '/sdk:sdk-repository/remotePackage/revision/micro=' | cut -d= -f 2-)"
latest_preview="$(echo "$latest" | grep '/sdk:sdk-repository/remotePackage/revision/preview=' | cut -d= -f 2-)"

latest_file="$(echo "$latest_linux" | grep '/sdk:sdk-repository/remotePackage/archives/archive/complete/url=' | cut -d= -f 2-)"
latest_sha1="$(echo "$latest_linux" | grep '/sdk:sdk-repository/remotePackage/archives/archive/complete/checksum=' | cut -d= -f 2-)" # assuming sha1 is the only checksum available

wget -q -c -O "$TOP/$latest_file" "https://dl.google.com/android/repository/$latest_file"
unpack_dir="$(unzip -qql "$TOP/$latest_file"  | sed -r '1 {s/([ ]+[^ ]+){3}\s+//;q}' | sed 's#/.*##')"

install -d "$TOP/android-build-tools-installer"
install -d "$TOP/android-build-tools-installer/for-postinst/"
echo "PKG_SOURCE:=$latest_file
UNPACK_DIR=\$(DL_DIR)/$unpack_dir" > "$TOP/android-build-tools-installer/for-postinst/Makefile"
tee -a "$TOP/android-build-tools-installer/for-postinst/Makefile" > /dev/null <<'EOFILE'
PKG_SOURCE_URL:=https://dl.google.com/android/repository/${PKG_SOURCE}

DL_DIR=/var/cache/android-build-tools-installer
DOC_DIR=/usr/share/doc/android-build-tools

all: $(DL_DIR)/$(UNPACK_DIR)/aapt
	sed -i 's,^libdir=.*,libdir=/usr/share/java,' $(UNPACK_DIR)/apksigner
	sed -i 's,^libdir=.*,libdir=/usr/share/java,' $(UNPACK_DIR)/d8

install: all
	install -d -m0755 /usr/share/java
	install -m0644 \
		$(UNPACK_DIR)/lib/apksigner.jar \
		$(UNPACK_DIR)/core-lambda-stubs.jar \
		$(UNPACK_DIR)/lib/d8.jar \
	 	/usr/share/java/
	install -d -m0755 /usr/bin
	install -m0755 \
		$(UNPACK_DIR)/aapt \
		$(UNPACK_DIR)/aapt2 \
		$(UNPACK_DIR)/aarch64-linux-android-ld \
		$(UNPACK_DIR)/aidl \
		$(UNPACK_DIR)/apksigner \
		$(UNPACK_DIR)/arm-linux-androideabi-ld \
		$(UNPACK_DIR)/bcc_compat \
		$(UNPACK_DIR)/d8 \
		$(UNPACK_DIR)/dexdump \
		$(UNPACK_DIR)/i686-linux-android-ld \
		$(UNPACK_DIR)/lld-bin/lld \
		$(UNPACK_DIR)/llvm-rs-cc \
		$(UNPACK_DIR)/mipsel-linux-android-ld \
		$(UNPACK_DIR)/split-select \
		$(UNPACK_DIR)/x86_64-linux-android-ld \
		$(UNPACK_DIR)/zipalign \
		/usr/bin/
	install -d -m0755 /usr/lib/
	for f in libbcc.so libbcinfo.so libc++.so libc++.so.1 libclang_android.so libconscrypt_openjdk_jni.so libLLVM_android.so; do \
		test -e /usr/bin/$$f || install -m0644 $(UNPACK_DIR)/lib64/$$f /usr/lib/; done
	install -d -m0755 $(DOC_DIR)
	gzip -9 --stdout $(UNPACK_DIR)/NOTICE.txt > $(DOC_DIR)/copyright.gz
	install -m0644 \
		$(UNPACK_DIR)/runtime.properties \
		$(UNPACK_DIR)/source.properties \
		/usr/share/android-build-tools-installer/
	for f in \
		$(DOC_DIR) \
		$(DOC_DIR)/copyright.gz \
		/usr/bin \
		/usr/bin/aapt \
		/usr/bin/aapt2 \
		/usr/bin/aarch64-linux-android-ld \
		/usr/bin/aidl \
		/usr/bin/apksigner \
		/usr/bin/arm-linux-androideabi-ld \
		/usr/bin/bcc_compat \
		/usr/bin/dexdump \
		/usr/bin/i686-linux-android-ld \
		/usr/bin/lld \
		/usr/bin/llvm-rs-cc \
		/usr/bin/mipsel-linux-android-ld \
		/usr/bin/split-select \
		/usr/bin/x86_64-linux-android-ld \
		/usr/bin/zipalign \
		/usr/lib \
		/usr/lib/libbcc.so \
		/usr/lib/libbcinfo.so \
		/usr/lib/libc++.so \
		/usr/lib/libc++.so.1 \
		/usr/lib/libclang_android.so \
		/usr/lib/libconscrypt_openjdk_jni.so \
		/usr/lib/libLLVM_android.so \
		/usr/share/android-build-tools-installer \
		/usr/share/android-build-tools-installer/runtime.properties \
		/usr/share/android-build-tools-installer/source.properties \
		/usr/share/java \
		/usr/share/java/apk-signer.jar \
		/usr/share/java/core-lambda-stubs.jar ; do echo $$f; done \
	>> /var/lib/dpkg/info/android-build-tools-installer.list

$(DL_DIR)/$(UNPACK_DIR)/aapt: $(DL_DIR)/$(PKG_SOURCE)
	cd $(DL_DIR) && unzip -ou $(PKG_SOURCE)

$(DL_DIR)/$(PKG_SOURCE): $(DL_DIR)
	cd $(DL_DIR) && \
		wget --continue $(PKG_SOURCE_URL)
	sha1sum -c $(PKG_SOURCE).sha1

$(DL_DIR):
	mkdir $(DL_DIR)

clean:
	-rm -rf -- $(UNPACK_DIR)

distclean: clean
	-rm -rf -- $(DL_DIR)

.PHONY: install clean

EOFILE

rm "$TOP/android-build-tools-installer/"*.sha1
echo "$latest_sha1  $latest_file" > "$TOP/android-build-tools-installer/$latest_file.sha1"
if [ -n "$latest_preview" ]; then
  versionname="$latest_major.$latest_minor.$latest_micro~rc$latest_preview+$d"
  versiontext="$latest_major.$latest_minor.$latest_micro-rc$latest_preview"
else
  versionname="$latest_major.$latest_minor.$latest_micro+$d"
  versiontext="$latest_major.$latest_minor.$latest_micro"
fi

rm -f "$TOP/android-build-tools-installer/debian/changelog"
pushd "$TOP/android-build-tools-installer" > /dev/null || exit 1
dch --create --force-distribution -v "$versionname" --package "android-build-tools-installer" -D "$d" -u low "Updated to Android Build tools $versiontext" #also possible to pass -M if you are the maintainer in the control file
popd > /dev/null || exit 1
echo "android-build-tools-installer_$versionname"
