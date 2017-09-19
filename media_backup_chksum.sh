#!/bin/sh

# ==============================================================================
#   機能
#     チェックサムファイルを生成する
#   構文
#     USAGE 参照
#
#   Copyright (c) 2013-2017 Yukio Shiiya
#
#   This software is released under the MIT License.
#   https://opensource.org/licenses/MIT
# ==============================================================================

######################################################################
# 変数定義
######################################################################
CHKSUM="sha256sum"

######################################################################
# 関数定義
######################################################################
USAGE() {
	cat <<- EOF 1>&2
		Usage:
		    media_backup_chksum.sh [OPTIONS ...] [ARGUMENTS ...]
		
		ARGUMENTS:
		    VOLUME_NAME : Specify volume name.
		
		OPTIONS:
		    --chksum=CHKSUM
		       Specify program name to compute checksum.
		       (default: ${CHKSUM})
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

# コマンドラインの表示・実行 (チェックサム)
CMD_V_CHKSUM() {
	for file in "$@" ; do
		if [ -f "${file}" ];then
			cmd_line="${CHKSUM} '${file}' >> '${CHKSUM_FILE}'"
			echo "+ ${cmd_line}"
			eval "${cmd_line}"
			if [ $? -ne 0 ];then
				echo "-E Command has ended unsuccessfully." 1>&2
				exit 1
			fi
		fi
	done
	return $?
}

######################################################################
# メインルーチン
######################################################################

# オプションのチェック
CMD_ARG="`getopt -o \"\" -l chksum:,help -- \"$@\" 2>&1`"
if [ $? -ne 0 ];then
	echo "-E ${CMD_ARG}" 1>&2
	USAGE;exit 1
fi
eval set -- "${CMD_ARG}"
while true ; do
	opt="$1"
	case "${opt}" in
	--chksum)	CHKSUM="$2" ; shift 2;;
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
	echo "-E Missing VOLUME_NAME argument" 1>&2
	USAGE;exit 1
else
	VOLUME_NAME="$1"
fi

# 変数定義(引数のチェック後)
CHKSUM_FILE="${VOLUME_NAME}.${CHKSUM}s"

# チェックサムファイルの生成
PROCESS_NAME="Checksum file making"
echo
echo "-I ${PROCESS_NAME} has started."
if [ -f "${CHKSUM_FILE}" ];then
	CMD_V "rm -i '${CHKSUM_FILE}'"
fi
if [ ! -f "${CHKSUM_FILE}" ];then
	CMD_V_CHKSUM "${VOLUME_NAME}".toc
	CMD_V_CHKSUM "${VOLUME_NAME}".cue
	CMD_V_CHKSUM "${VOLUME_NAME}".bin
	CMD_V_CHKSUM "${VOLUME_NAME}".iso
	CMD_V_CHKSUM "${VOLUME_NAME}".iso.isoinfo-d.log
	CMD_V "cat '${CHKSUM_FILE}'"
fi
echo "-I ${PROCESS_NAME} has ended successfully."

