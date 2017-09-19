#!/bin/bash

# ==============================================================================
#   機能
#     メディアをバックアップする
#   構文
#     USAGE 参照
#
#   Copyright (c) 2013-2017 Yukio Shiiya
#
#   This software is released under the MIT License.
#   https://opensource.org/licenses/MIT
# ==============================================================================

######################################################################
# 基本設定
######################################################################
trap "" 28				# TRAP SET
trap "POST_PROCESS;exit 1" 1 2 15	# TRAP SET

SCRIPT_FULL_NAME=`realpath $0`
SCRIPT_ROOT=`dirname ${SCRIPT_FULL_NAME}`
SCRIPT_NAME=`basename ${SCRIPT_FULL_NAME}`
PID=$$

######################################################################
# 変数定義
######################################################################
# ユーザ変数
DEST_FILE_VOL_TRK_SEPARATOR="_"
DEST_FILE_TRK_PRINTF_FORMAT="%02d"
DEST_FILE_EXT="wav"

# システム環境 依存変数
case `uname -s` in
CYGWIN_*)
	CDPARANOIA="cd-paranoia"
	;;
*)
	CDPARANOIA="cdparanoia"
	;;
esac
CDPARANOIA_FILE_PREFIX="track"
CDPARANOIA_FILE_TRK_PRINTF_FORMAT="%02d"
CDPARANOIA_FILE_SUFFIX="cdda.wav"
CDRDAO="cdrdao"
READOM="readom"

# プログラム内部変数
FLAG_OPT_APPEND=FALSE
LOG_FILE="./${SCRIPT_NAME}.log"
BACKUP_RETRY_NUM="10"
CDPARANOIA_OPTIONS=""
CDRDAO_OPTIONS=""
CDRDAO_DEVICE=""
READOM_OPTIONS=""

#DEBUG=TRUE
#TMP_DIR="/tmp"
TMP_DIR="."
SCRIPT_TMP_DIR="${TMP_DIR}/${SCRIPT_NAME}.${PID}"
BACKUP_DIR_TMP="${SCRIPT_TMP_DIR}/backup"

######################################################################
# 関数定義
######################################################################
PRE_PROCESS() {
	# 一時ディレクトリの作成
	mkdir -p "${SCRIPT_TMP_DIR}"
}

POST_PROCESS() {
	# 一時ディレクトリの削除
	if [ ! ${DEBUG} ];then
		rm -fr "${SCRIPT_TMP_DIR}"
	fi
}

USAGE() {
	cat <<- EOF 1>&2
		Usage:
		    media_backup.sh IN_TYPE OUT_FMT [OPTIONS ...] [ARGUMENTS ...]
		
		IN_TYPES:
		    cd-da         {wav}         [OPTIONS ...] SRC_DEV VOLUME_NAME TRACK_NUM ...
		       Backup only the audio with the specified track number.
		    cd-da         {cue/bin}     [OPTIONS ...] SRC_DEV VOLUME_NAME
		    mixed_mode_cd {cue/bin}     [OPTIONS ...] SRC_DEV VOLUME_NAME
		    cd-rom        {cue/bin|iso} [OPTIONS ...] SRC_DEV VOLUME_NAME
		    dvd-rom       {iso}         [OPTIONS ...] SRC_DEV VOLUME_NAME
		       Backup the whole media of the specified input type.
		
		ARGUMENTS:
		    SRC_DEV     : Specify source device file.
		    VOLUME_NAME : Specify volume name.
		    TRACK_NUM   : Specify track number.
		
		OPTIONS:
		    -a (append-log-file)
		       Append to an existing log file.
		    -l LOG_FILE
		       Specify a log file to output full message.
		       (default: ${LOG_FILE})
		    -t BACKUP_RETRY_NUM
		       This is the number of backup retry times.
		       Specify 0 or a positive integer as BACKUP_RETRY_NUM.
		       0 means infinite retrying.
		       (default: ${BACKUP_RETRY_NUM})
		    --cdparanoia-options="CDPARANOIA_OPTIONS ..."
		       Specify options which execute cdparanoia command with.
		       Following options are used internally.
		         -Bd
		       See also cdparanoia(1) for the further information on each option.
		    --cdrdao-options="CDRDAO_OPTIONS ..."
		       Specify options which execute cdrdao command with.
		       Following options are used internally.
		         --read-raw --device --datafile
		       See also cdrdao(1) for the further information on each option.
		    --cdrdao-device="CDRDAO_DEVICE"
		       Specify source device on a system where cdrdao does not support opening
		       via UNIX device file.
		       When this option is not specified, the value specified for "SRC_DEV" is
		       assumed.
		    --readom-options="READOM_OPTIONS ..."
		       Specify options which execute readom command with.
		       Following options are used internally.
		         dev=target f=filename
		       See also readom(1) for the further information on each option.
		    --help
		       Display this help and exit.
	EOF
}

. is_numeric_function.sh

# TRACK_NUM引数のチェック
ARGS_CHECK_TRACK_NUM() {
	for TRACK_NUM in "$@" ; do
		# 指定された文字列が数値か否かのチェック
		IS_NUMERIC "${TRACK_NUM}"
		if [ $? -ne 0 ];then
			echo "-E Argument \"TRACK_NUM\" not numeric -- \"${TRACK_NUM}\"" 1>&2
			USAGE;exit 1
		fi
	done
}

# LOG_FILE の初期化
INIT_LOG_FILE() {
	if [ "${FLAG_OPT_APPEND}" = "FALSE" ];then
		echo -n | tee "${LOG_FILE}" 2>/dev/null
	else
		echo -n | tee -a "${LOG_FILE}" 2>/dev/null
	fi
	if [ $? -ne 0 ];then
		echo "-E Cannot write file -- \"${LOG_FILE}\"" 1>&2
		USAGE;exit 1
	fi
}

# ログメッセージの表示
ECHO_LOG() {
	echo "$1" | tee -a "${LOG_FILE}"
}

# コマンドラインの表示・実行
CMD_LOG() {
	echo "+ $@" | tee -a "${LOG_FILE}"
	eval "$@" >> "${LOG_FILE}" 2>&1
	return $?
}
CMD_LOG_V() {
	echo "+ $@" | tee -a "${LOG_FILE}"
	eval "$@" 2>&1 | tee -a "${LOG_FILE}"
	return ${PIPESTATUS[0]}
}

# バックアップ共通処理
BACKUP_COMMON() {
	ECHO_LOG
	ECHO_LOG "-I ${PROCESS_NAME} has started."
	backup_result=1
	n=0
	# バックアップ回数(n)のループ
	# n<BACKUP_RETRY_NUM の場合はループ (BACKUP_RETRY_NUM=0 の場合は無限ループ)
	while [ \( ${n} -lt ${BACKUP_RETRY_NUM} \) -o \( ${BACKUP_RETRY_NUM} -eq 0 \) ];do
		n=`expr ${n} + 1`
		# バックアップコマンドの実行
		ECHO_LOG "-I Backup command execution count = \"${n}\""
		CMD_LOG "${CMD_LINE}"
		if [ $? -ne 0 ];then
			ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
			POST_PROCESS;exit 1
		fi
		# バックアップ結果のファイル格納用ディレクトリの作成
		CMD_LOG_V "mkdir ${BACKUP_DIR_TMP}${n}/"
		if [ $? -ne 0 ];then
			ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
			POST_PROCESS;exit 1
		fi
		# バックアップ結果のファイル名変更
		for (( i=0; i<${#DEST_FILE_IN[*]}; i++ )) ; do
			CMD_LOG_V "mv '${DEST_FILE_IN[${i}]}' ${BACKUP_DIR_TMP}${n}/'${DEST_FILE[${i}]}'"
			if [ $? -ne 0 ];then
				ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
				POST_PROCESS;exit 1
			fi
		done
		# 1回目のバックアップの場合
		if [ ${n} -eq 1 ];then
			if [ ${BACKUP_RETRY_NUM} -eq 1 ];then
				# ループ脱出
				backup_result=0
				break 1
			else
				# ループ継続
				continue
			fi
		fi
		# 1回目から(n-1)回目のバックアップ結果とn回目のバックアップ結果を比較
		ECHO_LOG "-I Comparing backup results..."
		for (( i=1; i<=$(expr ${n} - 1); i++ )) ; do
			CMD_LOG_V "diff -r -q -s ${BACKUP_DIR_TMP}${i}/ ${BACKUP_DIR_TMP}${n}/"
			# 一致した場合
			if [ $? -eq 0 ];then
				# ループ脱出
				backup_result=0
				break 2
			fi
		done
	done
	# バックアップ回数(n)のループが正常終了しなかった場合
	if [ ${backup_result} -ne 0 ];then
		ECHO_LOG "-E ${PROCESS_NAME} ended unsuccessfully, aborted" 1>&2
		POST_PROCESS;exit 1
	# バックアップ回数(n)のループが正常終了した場合
	else
		ECHO_LOG "-I Clean up backup results..."
		# 1回目から(n-1)回目のバックアップ結果を削除
		if [ ! ${DEBUG} ];then
			for (( i=1; i<=$(expr ${n} - 1); i++ )) ; do
				CMD_LOG_V "rm -r ${BACKUP_DIR_TMP}${i}/"
				if [ $? -ne 0 ];then
					ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
					POST_PROCESS;exit 1
				fi
			done
		fi
		# n回目のバックアップ結果のファイル名を変更
		CMD_LOG_V "mv ${BACKUP_DIR_TMP}${n}/* ."
		if [ $? -ne 0 ];then
			ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
			POST_PROCESS;exit 1
		fi
		# バックアップ結果のファイル格納用ディレクトリの削除
		CMD_LOG_V "rmdir ${BACKUP_DIR_TMP}${n}/"
		if [ $? -ne 0 ];then
			ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
			POST_PROCESS;exit 1
		fi
		ECHO_LOG "-I ${PROCESS_NAME} has ended successfully."
	fi
}

# 指定されたトラック番号のオーディオのみバックアップ
BACKUP_AUDIO_TRACK_NUM() {
	for TRACK_NUM in "$@" ; do
		PROCESS_NAME="AUDIO track backup (TRACK_NUM = ${TRACK_NUM})"
		unset DEST_FILE_IN ; unset DEST_FILE
		DEST_FILE_IN[0]="$(printf "${CDPARANOIA_FILE_PREFIX}${CDPARANOIA_FILE_TRK_PRINTF_FORMAT}.${CDPARANOIA_FILE_SUFFIX}" ${TRACK_NUM})"
		DEST_FILE[0]="$(printf "${VOLUME_NAME}${DEST_FILE_VOL_TRK_SEPARATOR}${DEST_FILE_TRK_PRINTF_FORMAT}.${DEST_FILE_EXT}" ${TRACK_NUM})"
		CMD_LINE="${CDPARANOIA} ${CDPARANOIA_OPTIONS:+${CDPARANOIA_OPTIONS} }-B -d ${SRC_DEV} ${TRACK_NUM}"
		BACKUP_COMMON
	done
}

# TOCファイルのバックアップ
BACKUP_TOC() {
	PROCESS_NAME="TOC file backup"
	unset DEST_FILE_IN ; unset DEST_FILE
	DEST_FILE_IN[0]="${VOLUME_NAME}_read-toc.toc"
	DEST_FILE[0]="${DEST_FILE_IN[0]}"
	CMD_LINE="${CDRDAO} read-toc ${CDRDAO_OPTIONS:+${CDRDAO_OPTIONS} }--read-raw --device ${CDRDAO_DEVICE} --datafile '${VOLUME_NAME}.bin' '${DEST_FILE_IN[0]}'"
	BACKUP_COMMON
}

# DATAトラックのバックアップ (MIXED_MODE_CD)
BACKUP_DATA_MIXED_MODE_CD() {
	PROCESS_NAME="DATA track backup (MIXED_MODE_CD)"
	unset DEST_FILE_IN ; unset DEST_FILE
	DEST_FILE_IN[0]="${VOLUME_NAME}_read-cd.toc"
	DEST_FILE[0]="${DEST_FILE_IN[0]}"
	DEST_FILE_IN[1]="${VOLUME_NAME}_read-cd.bin"
	DEST_FILE[1]="${DEST_FILE_IN[1]}"
	CMD_LINE="${CDRDAO} read-cd ${CDRDAO_OPTIONS:+${CDRDAO_OPTIONS} }--read-raw --device ${CDRDAO_DEVICE} --datafile '${DEST_FILE_IN[1]}' '${DEST_FILE_IN[0]}'"
	BACKUP_COMMON
}

# DATAトラックのバックアップ (CD_ROM)
BACKUP_DATA_CD_ROM() {
	PROCESS_NAME="DATA track backup (CD_ROM)"
	unset DEST_FILE_IN ; unset DEST_FILE
	DEST_FILE_IN[0]="${VOLUME_NAME}.toc"
	DEST_FILE[0]="${DEST_FILE_IN[0]}"
	DEST_FILE_IN[1]="${VOLUME_NAME}.bin"
	DEST_FILE[1]="${DEST_FILE_IN[1]}"
	CMD_LINE="${CDRDAO} read-cd ${CDRDAO_OPTIONS:+${CDRDAO_OPTIONS} }--read-raw --device ${CDRDAO_DEVICE} --datafile '${DEST_FILE_IN[1]}' '${DEST_FILE_IN[0]}'"
	BACKUP_COMMON
}

# DATAトラックのバックアップ
BACKUP_DATA() {
	PROCESS_NAME="DATA track backup"
	unset DEST_FILE_IN ; unset DEST_FILE
	DEST_FILE_IN[0]="${VOLUME_NAME}.iso"
	DEST_FILE[0]="${DEST_FILE_IN[0]}"
	CMD_LINE="${READOM} ${READOM_OPTIONS:+${READOM_OPTIONS} }dev=${SRC_DEV} f='${DEST_FILE_IN[0]}'"
	BACKUP_COMMON
}

# AUDIOトラックのバックアップ
BACKUP_AUDIO() {
	PROCESS_NAME="AUDIO track backup"
	unset DEST_FILE_IN ; unset DEST_FILE
	DEST_FILE_IN[0]="${VOLUME_NAME}.bin"
	DEST_FILE[0]="${DEST_FILE_IN[0]}"
	CMD_LINE="${CDPARANOIA} ${CDPARANOIA_OPTIONS:+${CDPARANOIA_OPTIONS} }-d ${SRC_DEV} '[00:00:00.00]-' '${DEST_FILE_IN[0]}'"
	BACKUP_COMMON
}

# TOCファイルの生成 (CD_DA)
MAKE_TOC_CD_DA() {
	PROCESS_NAME="TOC file making (CD_DA)"
	ECHO_LOG
	ECHO_LOG "-I ${PROCESS_NAME} has started."
	CMD_LOG_V "mv '${VOLUME_NAME}_read-toc.toc' '${VOLUME_NAME}.toc'"
	ECHO_LOG "-I ${PROCESS_NAME} has ended successfully."
}

# TOCファイルの生成 (MIXED_MODE_CD)
MAKE_TOC_MIXED_MODE_CD() {
	PROCESS_NAME="TOC file making (MIXED_MODE_CD)"
	ECHO_LOG
	ECHO_LOG "-I ${PROCESS_NAME} has started."
	CMD_LOG_V "cat '${VOLUME_NAME}_read-toc.toc' \
| sed 's/^DATAFILE \"${VOLUME_NAME}_1\"/DATAFILE \"${VOLUME_NAME}.bin\"/' \
> '${VOLUME_NAME}_wk.toc'"
	CMD_LOG_V "cat '${VOLUME_NAME}_wk.toc' \
| perl -ne '\
if (m/^DATAFILE .* \/\/ length in bytes: ([0-9]+)$/) { \
\$data_len = \$1; \
print; \
} elsif (m/^(FILE \"[^\"]+\" )(.+)$/) { \
print \"\$1#\$data_len \$2\n\"; \
} else { \
print; \
} \
' > '${VOLUME_NAME}.toc'"
	if [ ! ${DEBUG} ];then
		CMD_LOG_V "rm '${VOLUME_NAME}_wk.toc'"
	fi
	#CMD_LOG_V "diff -u '${VOLUME_NAME}_read-toc.toc' '${VOLUME_NAME}.toc'"
	CMD_LOG_V "diff '${VOLUME_NAME}_read-toc.toc' '${VOLUME_NAME}.toc'"
	if [ ! ${DEBUG} ];then
		CMD_LOG_V "rm '${VOLUME_NAME}_read-toc.toc'"
	fi
	ECHO_LOG "-I ${PROCESS_NAME} has ended successfully."
}

# CUEファイルの生成
MAKE_CUE() {
	PROCESS_NAME="CUE file making"
	ECHO_LOG
	ECHO_LOG "-I ${PROCESS_NAME} has started."
	CMD_LOG "toc2cue '${VOLUME_NAME}.toc' '${VOLUME_NAME}.cue'"
	if [ $? -ne 0 ];then
		ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
		POST_PROCESS;exit 1
	fi
	ECHO_LOG "-I ${PROCESS_NAME} has ended successfully."
}

# MIXED_MODE_CDの後処理
POST_PROCESS_MIXED_MODE_CD() {
	PROCESS_NAME="Post processing (MIXED_MODE_CD)"
	ECHO_LOG
	ECHO_LOG "-I ${PROCESS_NAME} has started."
	data_len=$(cat "${VOLUME_NAME}_read-cd.toc" | perl -ne 'if (m/^DATAFILE .* \/\/ length in bytes: ([0-9]+)$/) { print $1; } ')
	CMD_LOG_V "head -c ${data_len} '${VOLUME_NAME}_read-cd.bin' > '${VOLUME_NAME}_data_raw.bin'"
	if [ $? -ne 0 ];then
		ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
		POST_PROCESS;exit 1
	fi
	CMD_LOG_V "tail -c +$(expr ${data_len} + 1) '${VOLUME_NAME}_read-cd.bin' > '${VOLUME_NAME}_audio_PENDING_DELETE.bin'"
	if [ $? -ne 0 ];then
		ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
		POST_PROCESS;exit 1
	fi
	CMD_LOG_V "ls -al --sort=none '${VOLUME_NAME}_read-cd.bin' '${VOLUME_NAME}_data_raw.bin' '${VOLUME_NAME}_audio_PENDING_DELETE.bin'"
	if [ ! ${DEBUG} ];then
		CMD_LOG_V "rm '${VOLUME_NAME}_read-cd.toc'"
		CMD_LOG_V "rm '${VOLUME_NAME}_read-cd.bin'"
	fi

	CMD_LOG_V "mv '${VOLUME_NAME}.bin' '${VOLUME_NAME}_audio.bin'"
	file_size_keep=$(stat --format="%s" "${VOLUME_NAME}_audio.bin")
	file_size_del=$(stat --format="%s" "${VOLUME_NAME}_audio_PENDING_DELETE.bin")
	ECHO_LOG "$(printf "%-35s : %s\n" "File name" "File size")"
	ECHO_LOG "----------------------------------------------------"
	ECHO_LOG "$(printf "%-35s : %s\n" "${VOLUME_NAME}_audio.bin" ${file_size_keep})"
	ECHO_LOG "$(printf "%-35s : %s\n" "${VOLUME_NAME}_audio_PENDING_DELETE.bin" ${file_size_del})"
	if [ ${file_size_keep} -ne ${file_size_del} ];then
		ECHO_LOG "-E File size of above two files did not match. See log file." 1>&2
		POST_PROCESS;exit 1
	fi
	if [ ! ${DEBUG} ];then
		CMD_LOG_V "rm '${VOLUME_NAME}_audio_PENDING_DELETE.bin'"
	fi

	CMD_LOG_V "cat '${VOLUME_NAME}_data_raw.bin' '${VOLUME_NAME}_audio.bin' > '${VOLUME_NAME}.bin'"
	if [ $? -ne 0 ];then
		ECHO_LOG "-E Command has ended unsuccessfully. See log file." 1>&2
		POST_PROCESS;exit 1
	fi
	if [ ! ${DEBUG} ];then
		CMD_LOG_V "rm '${VOLUME_NAME}_data_raw.bin'"
		CMD_LOG_V "rm '${VOLUME_NAME}_audio.bin'"
	fi
	ECHO_LOG "-I ${PROCESS_NAME} has ended successfully."
}

######################################################################
# メインルーチン
######################################################################

# IN_TYPEのチェック
if [ "$1" = "" ];then
	echo "-E Missing IN_TYPE" 1>&2
	USAGE;exit 1
else
	case "$1" in
	cd-da|mixed_mode_cd|cd-rom|dvd-rom)
		IN_TYPE="$1"
		;;
	*)
		echo "-E Invalid IN_TYPE -- \"$1\"" 1>&2
		USAGE;exit 1
		;;
	esac
fi

# IN_TYPEをシフト
shift 1

# OUT_FMTのチェック
if [ "$1" = "" ];then
	echo "-E Missing OUT_FMT" 1>&2
	USAGE;exit 1
else
	case "${IN_TYPE}" in
	cd-da)
		case "$1" in
		wav|cue/bin)
			OUT_FMT="$1"
			;;
		*)
			echo "-E Invalid OUT_FMT -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	mixed_mode_cd)
		case "$1" in
		cue/bin)
			OUT_FMT="$1"
			;;
		*)
			echo "-E Invalid OUT_FMT -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	cd-rom)
		case "$1" in
		cue/bin|iso)
			OUT_FMT="$1"
			;;
		*)
			echo "-E Invalid OUT_FMT -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	dvd-rom)
		case "$1" in
		iso)
			OUT_FMT="$1"
			;;
		*)
			echo "-E Invalid OUT_FMT -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	esac
fi

# OUT_FMTをシフト
shift 1

# オプションのチェック
CMD_ARG="`getopt -o al:t: -l cdparanoia-options:,cdrdao-options:,cdrdao-device:,readom-options:,help -- \"$@\" 2>&1`"
if [ $? -ne 0 ];then
	echo "-E ${CMD_ARG}" 1>&2
	USAGE;exit 1
fi
eval set -- "${CMD_ARG}"
while true ; do
	opt="$1"
	case "${opt}" in
	-a)	FLAG_OPT_APPEND=TRUE ; shift 1;;
	-l)	LOG_FILE="$2" ; shift 2;;
	-t)
		# 指定された文字列が数値か否かのチェック
		IS_NUMERIC "$2"
		if [ $? -ne 0 ];then
			echo "-E Argument to \"${opt}\" not numeric -- \"$2\"" 1>&2
			USAGE;exit 1
		fi
		case ${opt} in
		-t)
			# 指定された数値のチェック
			if [ $2 -lt 0 ];then
				echo "-E Argument to \"${opt}\" is invalid -- \"$2\"" 1>&2
				USAGE;exit 1
			fi
			BACKUP_RETRY_NUM="$2" ; shift 2;;
		esac
		;;
	--cdparanoia-options)	CDPARANOIA_OPTIONS="${CDPARANOIA_OPTIONS:+${CDPARANOIA_OPTIONS} }$2" ; shift 2;;
	--cdrdao-options)	CDRDAO_OPTIONS="${CDRDAO_OPTIONS:+${CDRDAO_OPTIONS} }$2" ; shift 2;;
	--cdrdao-device)	CDRDAO_DEVICE="$2" ; shift 2;;
	--readom-options)	READOM_OPTIONS="${READOM_OPTIONS:+${READOM_OPTIONS} }$2" ; shift 2;;
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
	echo "-E Missing SRC_DEV argument" 1>&2
	USAGE;exit 1
else
	SRC_DEV="$1"
	# バックアップ元デバイスファイルのチェック
	if [ ! -e "${SRC_DEV}" ];then
		echo "-E SRC_DEV not exist -- \"${SRC_DEV}\"" 1>&2
		USAGE;exit 1
	fi
fi

# 第2引数のチェック
if [ "$2" = "" ];then
	echo "-E Missing VOLUME_NAME argument" 1>&2
	USAGE;exit 1
else
	VOLUME_NAME="$2"
fi

if [ \( "${IN_TYPE}" = "cd-da" \) -a \( "${OUT_FMT}" = "wav" \) ];then
	# 第3引数のチェック
	if [ "$3" = "" ];then
		echo "-E Missing TRACK_NUM argument" 1>&2
		USAGE;exit 1
	fi
	# 第1引数、第2引数をシフト
	shift 2
	# TRACK_NUM引数のチェック
	ARGS_CHECK_TRACK_NUM "$@"
fi

# 変数定義(引数のチェック後)
if [ "${CDRDAO_DEVICE}" = "" ];then
	CDRDAO_DEVICE="${SRC_DEV}"
fi

# LOG_FILE の初期化
INIT_LOG_FILE

# 作業開始前処理
PRE_PROCESS

#####################
# メインループ 開始 #
#####################

case ${IN_TYPE} in
cd-da)
	case ${OUT_FMT} in
	wav)
		BACKUP_AUDIO_TRACK_NUM "$@"
		;;
	cue/bin)
		BACKUP_TOC
		MAKE_TOC_CD_DA
		MAKE_CUE
		BACKUP_AUDIO
		;;
	esac
	;;
mixed_mode_cd)
	case ${OUT_FMT} in
	cue/bin)
		BACKUP_TOC
		MAKE_TOC_MIXED_MODE_CD
		MAKE_CUE
		BACKUP_DATA_MIXED_MODE_CD
		BACKUP_AUDIO
		POST_PROCESS_MIXED_MODE_CD
		;;
	esac
	;;
cd-rom)
	case ${OUT_FMT} in
	cue/bin)
		BACKUP_DATA_CD_ROM
		MAKE_CUE
		;;
	iso)
		BACKUP_DATA
		;;
	esac
	;;
dvd-rom)
	case ${OUT_FMT} in
	iso)
		BACKUP_DATA
		;;
	esac
	;;
esac

#####################
# メインループ 終了 #
#####################

# 作業終了後処理
POST_PROCESS;exit 0

