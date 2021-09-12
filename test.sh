iotdb_cli_bin_path="/home/lulu/projects/iotdb/cli/target/iotdb-cli-0.13.0-SNAPSHOT/sbin/"
iotdb_server_bin_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/sbin/"
iotdb_data_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/data/data/sequence/root.test.g_0/"

gen_data_path="/home/lulu/Downloads/dataset/"

benchmark_bin_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/"
benchmark_data_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/data/exception/0/"
benchmark_conf_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/conf/"
benchmark_conf_file="${benchmark_conf_path}config.properties"

iotdb_server_bin_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/sbin/"
iotdb_server_conf_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/conf/"
iotdb_conf_file="${iotdb_server_conf_path}iotdb-engine.properties"

ep_res_dir="/home/lulu/Downloads/dataset/exception_proportion/"
es_res_dir="/home/lulu/Downloads/dataset/exception_size/"
# each directory corresponds to a combination of encoding and compression 
# dir name: encoding-compression
encoding=("PLAIN" "TS_2DIFF" "RLE" "GORILLA")
compression=("UNCOMPRESSED" "SNAPPY" "LZ4" "GZIP")


ep_header=", 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9"
es_header=", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10"


################################
# impact of exception proportion
################################
# impact of exception proportion on write latency
ep_wl="${ep_res_dir}ep_wl.csv"
# impact of exception proportion on write throughput
ep_wt="${ep_res_dir}ep_wt.csv"
# impact of exception proportion on query latency
ep_ql="${ep_res_dir}ep_ql.csv"
# impact of exception proportion on query throughput
ep_qt="${ep_res_dir}ep_qt.csv"
# impact of exception proportion on disk usage
ep_du="${ep_res_dir}ep_du.csv"


##########################
# impact of exception size
##########################
# impact of exception size on write latency
es_wl="${es_res_dir}es_wl.csv"
# impact of exception size on write throughput
es_wt="${es_res_dir}es_wt.csv"
# impact of exception size on query latency
es_ql="${es_res_dir}es_ql.csv"
# impact of exception size on query throughput
es_qt="${es_res_dir}es_qt.csv"
# impact of exception size on disk usage
es_du="${es_res_dir}es_du.csv"


period=(1 2 3 4 5 6 7 8 9 10)
exception_size=(1 2 3 4 5 6 7 8 9 10)
exception_proportion=(0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9)


cleanDataDir() {
    cd ${benchmark_data_path}
    file_nums=$(ls -l | grep "^-" | wc -l)
    if [ ${file_nums} -gt 0 ]; then
        rm *.txt
    fi
}


genData() { 
    cd ${gen_data_path}
    python gen.py -p "batch" $1
    file_nums=a$(ls -l ${benchmark_data_path} | grep "^-" | wc -l)
}
 

toggleWriteMode() {
    sed -i -e "49c # BENCHMARK_WORK_MODE=testWithDefaultPath" \
        -e "50c BENCHMARK_WORK_MODE=verificationWriteMode" \
        -e "31c IS_DELETE_DATA=true" ${benchmark_conf_file}
}


toggleTestMode () {
    sed -i -e "49c BENCHMARK_WORK_MODE=testWithDefaultPath" \
        -e "50c # BENCHMARK_WORK_MODE=verificationWriteMode" \
        -e "31c IS_DELETE_DATA=false" ${benchmark_conf_file}
}


testWriteModeThroughputLatency() {
    cd ${benchmark_bin_path}
    res=$(./benchmark.sh 2>/dev/null)
    throughput=$(echo ${res} | grep -ozP "throughput(\n|.)*?\K(\d+\.\d+)" | tr -d '\0')
    avg_latency=$(echo ${res} | grep -ozP "AVG(\n|.)*?\K(\d+\.\d+)" | tr -d '\0')
    echo "throughput: " ${throughput} points/s, "average latency: " ${avg_latency} "s"
    echo -n "${avg_latency}, " >> $1
    echo -n "${throughput}, " >> $2
}


recordDiskUsage() { 
    cd ${iotdb_cli_bin_path}
    # flush mem_table to disk
    echo -e "flush\nexit" | ./start-cli.sh -h localhost -p 6667 -u root -pw root >/dev/null 2>&1
    cd ${iotdb_data_path}
    disk_usage=$(du -s | grep -ozP "\w+" | tr -d '\0')
    echo "disk usage: ${disk_usage}KB"
    echo -n "${disk_usage}, " >> $1
}


testTestModeThroughputLatency() {
    cd ${benchmark_bin_path}
    res=$(./benchmark.sh 2>/dev/null)
    throughput=$(echo ${res} 2>/dev/null | grep -ozP "TIME_RANGE\s+\d+\s+.*?\K(\d+\.\d+)" | tr -d '\0')
    avg_latency=$(echo ${res} 2>/dev/null | grep -ozP "TIME_RANGE\s*?\K(\d+\.\d+)" | tr -d '\0')
    echo "throughput: " ${throughput} points/s, "average latency: " ${avg_latency} "s"
    echo -n "${avg_latency}, " >> $1
    echo -n "${throughput}, " >> $2
}


# modify IotDB server configuration
#   $1: encoding
#   $2: compression
modifyIotDBServerConfig() {
    cd ${iotdb_server_conf_path}
    sed -i -e "665c default_float_encoding=$1" \
        -e "714c compressor=$2" ${iotdb_conf_file}
    printf "\nCurrent encoding = $1, compression = $2\n"
}


startIoTDBServer() {
    cd ${iotdb_server_bin_path}
    if [ ${server_pid} != "-1" ]; then
        kill -9 ${server_pid}
    fi
    server_pid=$(./start-server.sh >/dev/null 2>&1 & echo $!)
    printf "Current server running with pid = ${server_pid}\n"
}


# $1: encoding
# $2: compression
initEPResCSVFile() { 
    if [ ! -d ${ep_res_dir} ]; then
        mkdir ${ep_res_dir}
    fi
    cd ${ep_res_dir}

    if [ ! -f ${ep_wt} ]; then
        printf "${ep_header}" >> ${ep_wt}
    fi
    if [ ! -f ${ep_wl} ]; then
        printf "${ep_header}" >> ${ep_wl}
    fi
    if [ ! -f ${ep_qt} ]; then
        printf "${ep_header}" >> ${ep_qt}
    fi
    if [ ! -f ${ep_ql} ]; then
        printf "${ep_header}" >> ${ep_ql}
    fi
    if [ ! -f ${ep_du} ]; then
        printf "${ep_header}" >> ${ep_du}
    fi

    printf "\n$1_$2, " >> ${ep_wt}
    printf "\n$1_$2, " >> ${ep_wl}
    printf "\n$1_$2, " >> ${ep_qt}
    printf "\n$1_$2, " >> ${ep_ql}
    printf "\n$1_$2, " >> ${ep_du}
}


initESResCsvFile() { 
    if [ ! -d ${es_res_dir} ]; then
        mkdir ${es_res_dir}
    fi
    cd ${es_res_dir}

    if [ ! -f ${es_wt} ]; then
        printf "${es_header}" >> ${es_wt}
    fi
    if [ ! -f ${es_wl} ]; then
        printf "${es_header}" >> ${es_wl}
    fi
    if [ ! -f ${es_qt} ]; then
        printf "${es_header}" >> ${es_qt}
    fi
    if [ ! -f ${es_ql} ]; then
        printf "${es_header}" >> ${es_ql}
    fi
    if [ ! -f ${es_du} ]; then
        printf "${es_header}" >> ${es_du}
    fi

    printf "\n$1_$2, " >> ${es_wt}
    printf "\n$1_$2, " >> ${es_wl}
    printf "\n$1_$2, " >> ${es_qt}
    printf "\n$1_$2, " >> ${es_ql}
    printf "\n$1_$2, " >> ${es_du}
}


testExceptionProportion() {
    echo "Begin test of exception proportion impact"
    for e in ${encoding[@]}; do
        for c in ${compression[@]}; do
            modifyIotDBServerConfig ${e} ${c}
            startIoTDBServer
            initEPResCSVFile ${e} ${c}

            for p in ${exception_proportion[@]}; do
                cleanDataDir
                genData "-n ${p}"
                toggleWriteMode
                echo "Begin write mode with exception proportion ${p}"
                testWriteModeThroughputLatency ${ep_wl} ${ep_wt}
                recordDiskUsage ${ep_du}
                toggleTestMode
                echo "Begin test mode with exception proportion ${p}"
                testTestModeThroughputLatency ${ep_ql} ${ep_qt}
            done
        done
    done
    printf "Exception proportion test finished."
}


testExceptionSize() { 
    printf "Begin test of exception size impact\n"
    for e in ${encoding[@]}; do
        for c in ${compression[@]}; do
            modifyIotDBServerConfig ${e} ${c}
            startIoTDBServer
            initESResCsvFile ${e} ${c}

            for s in ${exception_size[@]}; do
                cleanDataDir
                genData "-f ${s}"
                toggleWriteMode
                printf "Begin write mode with exception size ${s}\n"
                testWriteModeThroughputLatency ${es_wl} ${es_wt}
                recordDiskUsage ${es_du}
                toggleTestMode
                printf "Begin test mode with exception size ${s}\n"
                testTestModeThroughputLatency ${es_ql} ${es_qt}
            done
        done
    done
    printf "Exception size test finished"
}


onCtrlC() { 
    printf "Ctrl+C captured"
    if [ ${server_pid} != "-1" ]; then
        kill -9 ${server_pid}
    fi
    exit
}


trap 'onCtrlC' SIGINT

server_pid=-1  #  pid of iotdb server
# testExceptionProportion
testExceptionSize