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
  trusty|xenial|yakkety|zesty);;
  clean) rm build-tools_*.zip; exit 0;;
  *) echo "Unrecognized Ubuntu version, use a valid distribution as 1st argument"; exit 1;;
esac

for repv in $(seq 15 -1 4); do  # start at 15, that should be relatively safe for the near future, since we know the current protocol is on 12 (feb 2016); we know 5 is still valid
  if wget -q --spider "https://dl-ssl.google.com/android/repository/repository-$repv.xml"; then
    break
  fi
done
if [ "$repv" = "4" ]; then # we know 4 does not really exist and is an invalid result
  echo "Could not fetch Google's Android Tools XML repository"
  exit 1
fi

latest="$(wget -q -O - "https://dl-ssl.google.com/android/repository/repository-$repv.xml" | xml2 | grep '/sdk:sdk-repository/sdk:build-tool/' | sed -e '\#/sdk:sdk-repository/sdk:build-tool/sdk:uses-license/#,$d')"
latest_rev="$(wget -q -O - "https://dl-ssl.google.com/android/repository/repository-$repv.xml" | xml2 | tac | grep '/sdk:sdk-repository/sdk:build-tool/' | sed -e '\#/sdk:sdk-repository/sdk:build-tool/!=#,$d')"
latest_linux="$(echo "$latest" | sed -e '\#sdk:sdk-repository/sdk:build-tool/sdk:archives/sdk:archive/sdk:host-os=linux#,$d' | tail -n 5)" # assuming there are 5 lines for this result
latest_linux_rev="$(echo "$latest_rev" | sed -n -e '\#sdk:sdk-repository/sdk:build-tool/sdk:archives/sdk:archive/sdk:host-os=linux#,$p' | head -n 5)" # assuming there are 5 lines for each build-tool result
latest_major="$(echo "$latest" | grep '/sdk:sdk-repository/sdk:build-tool/sdk:revision/sdk:major=' | cut -d= -f 2-)"
latest_major_rev="$(echo "$latest_rev" | grep '/sdk:sdk-repository/sdk:build-tool/sdk:revision/sdk:major=' | cut -d= -f 2-)"
if [ "$latest_major_rev" -gt "$latest_major" ]; then  # try to find out if the highest versionnumber is at the top or at the bottom of the XML data
  latest="$latest_rev"
  latest_linux="$latest_linux_rev"
  latest_major="$latest_major_rev"
fi

latest_minor="$(echo "$latest" | grep '/sdk:sdk-repository/sdk:build-tool/sdk:revision/sdk:minor=' | cut -d= -f 2-)"
latest_micro="$(echo "$latest" | grep '/sdk:sdk-repository/sdk:build-tool/sdk:revision/sdk:micro=' | cut -d= -f 2-)"
latest_preview="$(echo "$latest" | grep '/sdk:sdk-repository/sdk:build-tool/sdk:revision/sdk:preview=' | cut -d= -f 2-)"

latest_file="$(echo "$latest_linux" | grep '/sdk:sdk-repository/sdk:build-tool/sdk:archives/sdk:archive/sdk:url=' | cut -d= -f 2-)"
latest_sha1="$(echo "$latest_linux" | grep '/sdk:sdk-repository/sdk:build-tool/sdk:archives/sdk:archive/sdk:checksum=' | cut -d= -f 2-)" # assuming sha1 is the only checksum available

wget -q -c -O "$TOP/$latest_file" "https://dl-ssl.google.com/android/repository/$latest_file"
unpack_dir="$(unzip -qql "$TOP/$latest_file"  | sed -r '1 {s/([ ]+[^ ]+){3}\s+//;q}' | sed 's#/##')"

install -d "$TOP/android-build-tools-installer"
install -d "$TOP/android-build-tools-installer/for-postinst/"
echo "PKG_SOURCE:=$latest_file
UNPACK_DIR=\$(DL_DIR)/$unpack_dir" > "$TOP/android-build-tools-installer/for-postinst/Makefile"
tee -a "$TOP/android-build-tools-installer/for-postinst/Makefile" > /dev/null <<'EOFILE'
PKG_SOURCE_URL:=https://dl-ssl.google.com/android/repository/${PKG_SOURCE}

DL_DIR=/var/cache/android-build-tools-installer
DOC_DIR=/usr/share/doc/android-build-tools

all: $(DL_DIR)/$(UNPACK_DIR)/aapt
	sed -i 's,^libdir=.*,libdir=/usr/share/java,' $(UNPACK_DIR)/dx
	sed -i 's,^libdir=.*,libdir=/usr/share/java,' $(UNPACK_DIR)/mainDexClasses
	sed -i 's,^baserules=.*,baserules=/usr/share/android-build-tools-installer/mainDexClasses.rules,' $(UNPACK_DIR)/mainDexClasses

install: all
	install -d -m0755 /usr/share/java
	install -m0644\
		$(UNPACK_DIR)/lib/dx.jar\
		$(UNPACK_DIR)/lib/shrinkedAndroid.jar\
	 	/usr/share/java/
	install -d -m0755 /usr/bin
	install -m0755 \
		$(UNPACK_DIR)/aapt \
		$(UNPACK_DIR)/aarch64-linux-android-ld \
		$(UNPACK_DIR)/aidl \
		$(UNPACK_DIR)/arm-linux-androideabi-ld \
		$(UNPACK_DIR)/bcc_compat \
		$(UNPACK_DIR)/dexdump \
		$(UNPACK_DIR)/dx \
		$(UNPACK_DIR)/mainDexClasses \
		$(UNPACK_DIR)/i686-linux-android-ld \
		$(UNPACK_DIR)/llvm-rs-cc \
		$(UNPACK_DIR)/mipsel-linux-android-ld \
		$(UNPACK_DIR)/split-select \
		$(UNPACK_DIR)/zipalign \
		/usr/bin/
	install -d -m0755 /usr/lib/
	for f in libbcc.so libbcinfo.so libclang.so libc++.so libLLVM.so; do \
		test -e /usr/bin/$$f || install -m0644 $(UNPACK_DIR)/lib64/$$f /usr/lib/; done
	install -d -m0755 $(DOC_DIR)
	gzip -9 --stdout $(UNPACK_DIR)/NOTICE.txt > $(DOC_DIR)/copyright.gz
	install -m0644\
		$(UNPACK_DIR)/jack.jar\
		$(UNPACK_DIR)/jill.jar\
		$(UNPACK_DIR)/mainDexClasses.rules \
		$(UNPACK_DIR)/source.properties \
		$(UNPACK_DIR)/runtime.properties \
		/usr/share/android-build-tools-installer/
	for f in \
		$(DOC_DIR) \
		$(DOC_DIR)/copyright.gz \
		/usr/bin \
		/usr/bin/aapt \
		/usr/bin/aarch64-linux-android-ld \
		/usr/bin/aidl \
		/usr/bin/arm-linux-androideabi-ld \
		/usr/bin/bcc_compat \
		/usr/bin/dexdump \
		/usr/bin/dx \
		/usr/bin/mainDexClasses \
		/usr/bin/i686-linux-android-ld \
		/usr/bin/llvm-rs-cc \
		/usr/bin/mipsel-linux-android-ld \
		/usr/bin/split-select \
		/usr/bin/zipalign \
		/usr/lib \
		/usr/lib/libbcc.so \
		/usr/lib/libbcinfo.so \
		/usr/lib/libclang.so \
		/usr/lib/libc++.so \
		/usr/lib/libLLVM.so \
		/usr/share/android-build-tools-installer \
		/usr/share/android-build-tools-installer/jack.jar\
		/usr/share/android-build-tools-installer/jill.jar\
		/usr/share/android-build-tools-installer/mainDexClasses.rules \
		/usr/share/android-build-tools-installer/runtime.properties \
		/usr/share/android-build-tools-installer/source.properties \
		/usr/share/java \
		/usr/share/java/dx.jar \
		/usr/share/java/shrinkedAndroid.jar ; do echo $$f; done \
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
  versionname="$latest_major.$latest_minor.$latest_micro~rc$latest_preview-ubuntu0~$d"
  versiontext="$latest_major.$latest_minor.$latest_micro-rc$latest_preview"
else
  versionname="$latest_major.$latest_minor.$latest_micro-ubuntu0~$d"
  versiontext="$latest_major.$latest_minor.$latest_micro"
fi

rm -f "$TOP/android-build-tools-installer/debian/changelog"
pushd "$TOP/android-build-tools-installer" > /dev/null
dch --create -v "$versionname" --package "android-build-tools-installer" -D "$d" -u low "Updated to Android Build tools $versiontext" #also possible to pass -M if you are the maintainer in the control file
popd > /dev/null
echo "android-build-tools-installer_$versionname"
