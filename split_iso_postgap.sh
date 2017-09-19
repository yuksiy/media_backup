#!/bin/sh

# ==============================================================================
#   機能
#     ISOファイルのPostgapを分割する
#   構文
#     USAGE 参照
#
#   Copyright (c) 2013-2017 Yukio Shiiya
#
#   This software is released under the MIT License.
#   https://opensource.org/licenses/MIT
# ==============================================================================

######################################################################
# 関数定義
######################################################################
USAGE() {
	cat <<- EOF 1>&2
		Usage:
		    split_iso_postgap.sh [OPTIONS ...] [ARGUMENTS ...]
		
		ARGUMENTS:
		    ISO_FILE : Specify iso file.
		
		OPTIONS:
		    --help
		       Display this help and exit.
	EOF
}

# コマンドラインの表示・実行
CMD_V() {
	echo "+ $@"
	eval "$@"
	return $?
}

######################################################################
# メインルーチン
######################################################################

# オプションのチェック
CMD_ARG="`getopt -o \"\" -l help -- \"$@\" 2>&1`"
if [ $? -ne 0 ];then
	echo "-E ${CMD_ARG}" 1>&2
	USAGE;exit 1
fi
eval set -- "${CMD_ARG}"
while true ; do
	opt="$1"
	case "${opt}" in
	--help)
		USAGE;exit 0
		;;
	--)
		shift 1;break
		;;
	esac
done

# 第1引数のチェック
if [ "$1" = "" ];then
	echo "-E Missing ISO_FILE argument" 1>&2
	USAGE;exit 1
else
	ISO_FILE="$1"
	# ISOファイルのチェック
	if [ ! -f "${ISO_FILE}" ];then
		echo "-E ISO_FILE not a file -- \"${ISO_FILE}\"" 1>&2
		USAGE;exit 1
	fi
fi

# 変数定義(引数のチェック後)
SPLIT_ISO="$(echo "${ISO_FILE}" | sed 's/\.\(iso\)$/_split.\1/i')"
SPLIT_ISO_POSTGAP="${SPLIT_ISO}.postgap"

# Postgapの分割
PROCESS_NAME="Postgap splitting"
echo
echo "-I ${PROCESS_NAME} has started."
block_size=$(LANG=C isoinfo -d -i "${ISO_FILE}" | sed -n 's#^Logical block size is: \(.*\)$#\1#p')
vol_size=$(LANG=C isoinfo -d -i "${ISO_FILE}" | sed -n 's#^Volume size is: \(.*\)$#\1#p')
file_size=$(stat --format='%s' "${ISO_FILE}")
file_size_expected=$(expr ${block_size} \* ${vol_size})
echo "$(printf "%-35s : %s\n" "File name" "${ISO_FILE}")"
echo "$(printf "%-35s : %s\n" "Logical block size" ${block_size})"
echo "$(printf "%-35s : %s\n" "Volume size" ${vol_size})"
echo "----------------------------------------------------"
echo "$(printf "%-35s : %s\n" "Observed file size" ${file_size})"
echo "$(printf "%-35s : %s\n" "Expected file size" ${file_size_expected})"
if [ ${file_size} -lt ${file_size_expected} ];then
	CMD_V "ls -al --sort=none '${ISO_FILE}'"
	echo "-E Observed file may be corrupted. (Observed file size < Expected file size)" 1>&2
	echo "-E ${PROCESS_NAME} has ended unsuccessfully." 1>&2
	exit 1
elif [ ${file_size} -eq ${file_size_expected} ];then
	CMD_V "ls -al --sort=none '${ISO_FILE}'"
	echo "##################"
	echo "# Nothing to do. #"
	echo "##################"
else
	CMD_V "head -c ${file_size_expected} '${ISO_FILE}' > '${SPLIT_ISO}'"
	if [ $? -ne 0 ];then
		echo "-E Command has ended unsuccessfully." 1>&2
		exit 1
	fi
	CMD_V "tail -c +$(expr ${file_size_expected} + 1) '${ISO_FILE}' > '${SPLIT_ISO_POSTGAP}'"
	if [ $? -ne 0 ];then
		echo "-E Command has ended unsuccessfully." 1>&2
		exit 1
	fi
	CMD_V "ls -al --sort=none '${ISO_FILE}' '${SPLIT_ISO}' '${SPLIT_ISO_POSTGAP}'"
fi
echo "-I ${PROCESS_NAME} has ended successfully."

