#!/usr/bin/env bash

set -eux

. .github/scripts/common.sh


if [ "${OS}" = "Windows" ] ; then
	GHCUP_DIR="${GHCUP_INSTALL_BASE_PREFIX}"/ghcup
else
	GHCUP_DIR="${GHCUP_INSTALL_BASE_PREFIX}"/.ghcup
fi

env
git_describe

rm -rf "${GHCUP_DIR}"
mkdir -p "${GHCUP_BIN}"

cp "out/${ARTIFACT}"-* "$GHCUP_BIN/ghcup${ext}"
cp "out/test-${ARTIFACT}"-* "ghcup-test${ext}"
cp "out/test-optparse-${ARTIFACT}"-* "ghcup-test-optparse${ext}"
chmod +x "$GHCUP_BIN/ghcup${ext}"
chmod +x "ghcup-test${ext}"
chmod +x "ghcup-test-optparse${ext}"

"$GHCUP_BIN/ghcup${ext}" --version
eghcup --version
sha_sum "$GHCUP_BIN/ghcup${ext}"
sha_sum "$(raw_eghcup --offline whereis ghcup)"

### Haskell test suite

./"ghcup-test${ext}"
./"ghcup-test-optparse${ext}"
rm "ghcup-test${ext}" "ghcup-test-optparse${ext}"

### manual cli based testing

eghcup --numeric-version

# test PATH on windows wrt msys2
# https://github.com/haskell/ghcup-hs/pull/992/checks
if [ "${OS}" = "Windows" ] ; then
	eghcup run -m -- sh -c 'echo $PATH' | sed 's/:/\n/' | grep '^/mingw64/bin$'
fi

eghcup install ghc "${GHC_VER}"
eghcup unset ghc "${GHC_VER}"
ls -lah "$(eghcup whereis -d ghc "${GHC_VER}")"
[ "$($(eghcup whereis ghc "${GHC_VER}") --numeric-version)" = "${GHC_VER}" ]
[ "$(eghcup run -q --ghc "${GHC_VER}" -- ghc --numeric-version)" = "${GHC_VER}" ]
[ "$(ghcup run -q --ghc "${GHC_VER}" -- ghc -e 'Control.Monad.join (Control.Monad.fmap System.IO.putStr System.Environment.getExecutablePath)')" = "$($(ghcup whereis ghc "${GHC_VER}") -e 'Control.Monad.join (Control.Monad.fmap System.IO.putStr System.Environment.getExecutablePath)')" ]
eghcup set ghc "${GHC_VER}"
eghcup install cabal "${CABAL_VER}"
[ "$($(eghcup whereis cabal "${CABAL_VER}") --numeric-version)" = "${CABAL_VER}" ]
eghcup unset cabal
"$GHCUP_BIN"/cabal --version && exit 1 || echo yes

# make sure no cabal is set when running 'ghcup run' to check that PATH propagages properly
# https://gitlab.haskell.org/haskell/ghcup-hs/-/issues/375
[ "$(eghcup run -q --cabal "${CABAL_VER}" -- cabal --numeric-version)" = "${CABAL_VER}" ]
eghcup set cabal "${CABAL_VER}"

[ "$($(eghcup whereis cabal "${CABAL_VER}") --numeric-version)" = "${CABAL_VER}" ]

if [ "${OS}" != "FreeBSD" ] ; then
	if [ "${ARCH}" = "64" ] && [ "${DISTRO}" != "Alpine" ] ; then
		eghcup run --ghc 8.10.7 --cabal 3.4.1.0 --hls 1.6.1.0 --stack 2.7.3 --install --bindir "$(pwd)/.bin"
		if [ "${OS}" = "Windows" ] ; then
			cat "$( cd "$(dirname "$0")" ; pwd -P )/../ghcup-run.files.windows" | sort > expected.txt
		elif [ "${DISTRO}" = "Alpine" ] ; then
			cat "$( cd "$(dirname "$0")" ; pwd -P )/../ghcup-run.files.alpine" | sort > expected.txt
		else
			cat "$( cd "$(dirname "$0")" ; pwd -P )/../ghcup-run.files" | sort > expected.txt
		fi
		(cd ".bin" && find . | sort) > actual.txt
		diff --strip-trailing-cr -w -u actual.txt expected.txt
		rm actual.txt expected.txt
		rm -rf .bin
	fi
fi

cabal --version

eghcup debug-info

# also test etags
eghcup list
eghcup list -t ghc
eghcup list -t cabal

ghc_ver=$(ghc --numeric-version)
ghc --version
"ghc-${ghc_ver}" --version
if [ "${OS}" != "Windows" ] ; then
		ghci --version
		"ghci-${ghc_ver}" --version
fi


if [ "${OS}" = "macOS" ] && [ "${ARCH}" = "ARM64" ] ; then
	# missing bindists
	echo
elif [ "${OS}" = "FreeBSD" ] ; then
	# not enough space
	echo
elif [ "${OS}" = "Linux" ] && [ "${ARCH}" = "ARM64" ] && [ "${DISTRO}" = "Alpine" ]; then
	# missing bindists
	echo
else
	# test installing new ghc doesn't mess with currently set GHC
	# https://gitlab.haskell.org/haskell/ghcup-hs/issues/7
	if [ "${OS}" = "Linux" ] ; then
		eghcup --downloader=wget prefetch ghc 8.10.3
		eghcup --offline install ghc 8.10.3
		if [ "${ARCH}" = "64" ] ; then
		    if [ "${DISTRO}" = "Alpine" ] ; then
				(cat "$( cd "$(dirname "$0")" ; pwd -P )/../ghc-8.10.3-linux.alpine.files" | sort) > expected.txt
			else
				(cat "$( cd "$(dirname "$0")" ; pwd -P )/../ghc-8.10.3-linux.files" | sort) > expected.txt
			fi
			(cd "${GHCUP_DIR}/ghc/8.10.3/" && find . | sort) > actual.txt
			# ignore docs
		    sed -i '/share\/doc/d' actual.txt
		    sed -i '/share\/doc/d' expected.txt
			diff --strip-trailing-cr -w -u actual.txt expected.txt
			rm actual.txt expected.txt
		fi
	elif [ "${OS}" = "Windows" ] ; then
		eghcup prefetch ghc 8.10.3
		eghcup --offline install ghc 8.10.3
		(cat "$( cd "$(dirname "$0")" ; pwd -P )/../ghc-8.10.3-windows.files" | sort) > expected.txt
		(cd "${GHCUP_DIR}/ghc/8.10.3/" && find . | sort) > actual.txt
		diff --strip-trailing-cr -w -u actual.txt expected.txt
		rm actual.txt expected.txt
	else
		eghcup prefetch ghc 8.10.3
		eghcup --offline install ghc 8.10.3
	fi
	[ "$(ghc --numeric-version)" = "${ghc_ver}" ]
	eghcup --offline set 8.10.3
	eghcup set 8.10.3
	[ "$(ghc --numeric-version)" = "8.10.3" ]
	eghcup set "${GHC_VER}"
	[ "$(ghc --numeric-version)" = "${ghc_ver}" ]
	eghcup unset ghc
    "$GHCUP_BIN"/ghc --numeric-version && exit 1 || echo yes
	eghcup set "${GHC_VER}"
	eghcup --offline rm 8.10.3
	[ "$(ghc --numeric-version)" = "${ghc_ver}" ]


	ls -lah "$GHCUP_BIN"

	if [ "${OS}" = "macOS" ] ; then
		eghcup install hls
		$(eghcup whereis hls) --version

		eghcup install stack
		$(eghcup whereis stack) --version
	elif [ "${OS}" = "Linux" ] ; then
		if [ "${ARCH}" = "64" ] && [ "${DISTRO}" != "Alpine" ] ; then
			eghcup install hls
			haskell-language-server-wrapper --version
			eghcup unset hls
			"$GHCUP_BIN"/haskell-language-server-wrapper --version && exit 1 || echo yes

			eghcup install stack
			stack --version
			eghcup unset stack
			"$GHCUP_BIN"/stack --version && exit 1 || echo yes
		fi
	fi
fi



# check that lazy loading works for 'whereis'
cp "$CI_PROJECT_DIR/data/metadata/ghcup-${JSON_VERSION}.yaml" "$CI_PROJECT_DIR/data/metadata/ghcup-${JSON_VERSION}.yaml.bak"
echo '**' > "$CI_PROJECT_DIR/data/metadata/ghcup-${JSON_VERSION}.yaml"
eghcup whereis ghc "$(ghc --numeric-version)"
mv -f "$CI_PROJECT_DIR/data/metadata/ghcup-${JSON_VERSION}.yaml.bak" "$CI_PROJECT_DIR/data/metadata/ghcup-${JSON_VERSION}.yaml"

eghcup rm "$(ghc --numeric-version)"

# https://gitlab.haskell.org/haskell/ghcup-hs/-/issues/116
if [ "${OS}" = "Linux" ] ; then
	if [ "${ARCH}" = "64" ] ; then
		eghcup install cabal -u https://downloads.haskell.org/~ghcup/unofficial-bindists/cabal/3.7.0.0-pre20220407/cabal-install-3.7-x86_64-linux-alpine.tar.xz 3.4.0.0-rc4
		eghcup rm cabal 3.4.0.0-rc4
	fi
fi

eghcup gc -c

# test etags
rm -f "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml"
raw_eghcup -s "https://www.haskell.org/ghcup/data/ghcup-${JSON_VERSION}.yaml" list
# snapshot yaml and etags file
etag=$(cat "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml.etags")
sha=$(sha_sum "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml")
# invalidate access time timer, which is 5minutes, so we re-download
touch -a -m -t '199901010101' "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml"
# redownload same file with some newlines added
raw_eghcup -s https://raw.githubusercontent.com/haskell/ghcup-metadata/exp/ghcup-${JSON_VERSION}.yaml list
# snapshot new yaml and etags file
etag2=$(cat "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml.etags")
sha2=$(sha_sum "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml")
# compare
[ "${etag}" != "${etag2}" ]
[ "${sha}" != "${sha2}" ]
# invalidate access time timer, which is 5minutes, but don't expect a re-download
touch -a -m -t '199901010101' "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml"
# this time, we expect the same hash and etag
raw_eghcup -s https://raw.githubusercontent.com/haskell/ghcup-metadata/exp/ghcup-${JSON_VERSION}.yaml list
etag3=$(cat "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml.etags")
sha3=$(sha_sum "${GHCUP_DIR}/cache/ghcup-${JSON_VERSION}.yaml")
[ "${etag2}" = "${etag3}" ]
[ "${sha2}" = "${sha3}" ]

# test isolated installs
if [ "${DISTRO}" != "Alpine" ] ; then
	eghcup install ghc -i "$(pwd)/isolated" 8.10.5
	[ "$(isolated/bin/ghc --numeric-version)" = "8.10.5" ]
	! eghcup install ghc -i "$(pwd)/isolated" 8.10.5
	if [ "${ARCH}" = "64" ] ; then
		if [ "${OS}" = "Linux" ] || [ "${OS}" = "Windows" ] ; then
			eghcup install cabal -i "$(pwd)/isolated" 3.4.0.0
			[ "$(isolated/cabal --numeric-version)" = "3.4.0.0" ]
			eghcup install stack -i "$(pwd)/isolated" 2.7.3
			[ "$(isolated/stack --numeric-version)" = "2.7.3" ]
			eghcup install hls -i "$(pwd)/isolated" 1.3.0
			[ "$(isolated/haskell-language-server-wrapper --numeric-version)" = "1.3.0" ] ||
				[ "$(isolated/haskell-language-server-wrapper --numeric-version)" = "1.3.0.0" ]

			# test that isolated installs don't clean up target directory
			cat <<EOF > "${GHCUP_BIN}/gmake"
#!/bin/bash
exit 1
EOF
			chmod +x "${GHCUP_BIN}/gmake"
			mkdir isolated_tainted/
			touch isolated_tainted/lol

			! eghcup install ghc -i "$(pwd)/isolated_tainted" 8.10.5 --force
			[ -e "$(pwd)/isolated_tainted/lol" ]
			rm "${GHCUP_BIN}/gmake"
		fi
	fi
fi

eghcup upgrade
eghcup upgrade -f

# restore old ghcup, because we want to test nuke
cp "out/${ARTIFACT}"-* "$GHCUP_BIN/ghcup${ext}"
chmod +x "$GHCUP_BIN/ghcup${ext}"

# test that doing fishy symlinks into GHCup dir doesn't cause weird stuff on 'ghcup nuke'
mkdir no_nuke/
mkdir no_nuke/bar
echo 'foo' > no_nuke/file
echo 'bar' > no_nuke/bar/file
ln -s "$CI_PROJECT_DIR"/no_nuke/ "${GHCUP_DIR}"/cache/no_nuke
ln -s "$CI_PROJECT_DIR"/no_nuke/ "${GHCUP_DIR}"/logs/no_nuke

# nuke
eghcup nuke
[ ! -e "${GHCUP_DIR}" ]

# make sure nuke doesn't resolve symlinks
[ -e "$CI_PROJECT_DIR"/no_nuke/file ]
[ -e "$CI_PROJECT_DIR"/no_nuke/bar/file ]

