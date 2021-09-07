iotdb_server_bin_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/sbin/"

gen_data_path="/home/lulu/Downloads/dataset/"

benchmark_bin_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/"
benchmark_data_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/data/exception/0/"
benchmark_conf_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/conf/"
benchmark_conf_file="${benchmark_conf_path}config.properties"

iotdb_server_bin_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/sbin/"
iotdb_server_conf_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/conf/"
iotdb_conf_file="${iotdb_server_conf_path}iotdb-engine.properties"

# result directory
res_dir="/home/lulu/Downloads/dataset/exception_proportion/"
# each directory corresponds to a combination of encoding and compression 
# dir name: encoding-compression
encoding=("PLAIN" "TS_2DIFF" "RLE" "GORILLA")
compression=("UNCOMPRESSED" "SNAPPY" "LZ4" "GZIP")


ep_header="Exception Proportion, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9"


################################
# impact of exception proportion
################################
# impact of exception proportion on write latency
ep_wl="ep_wl.csv"
# impact of exception proportion on write throughput
ep_wt="ep_wt.csv"
# impact of exception proportion on query latency
ep_ql="ep_ql.csv"
# impact of exception proportion on query throughput
ep_qt="ep_qt.csv"


##########################
# impact of exception size
##########################
# impact of exception size on write latency
es_wl="es_wl.csv"
# impact of exception size on write throughput
es_wt="es_wt.csv"
# impact of exception size on query latency
es_ql="es_ql.csv"
# impact of exception size on query throughput
es_qt="es_qt.csv"


period=(1 2 3 4 5 6 7 8 9 10)
exception_size=(1 2 3 4 5 6 7 8 9 10)
exception_proportion=(0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9)


cleanDataDir() {
    cd ${benchmark_data_path}
    file_nums=`ls -l | grep "^-" | wc -l`
    if [ ${file_nums} -gt 0 ]; then
        rm *.txt
    fi
}


genData() { 
    cd ${gen_data_path}
    python gen.py -p "batch" -n $1
    file_nums=`ls -l ${benchmark_data_path} | grep "^-" | wc -l`
    printf "\n${file_nums} files generated\n\n"
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
    res=`./benchmark.sh`
    throughput=`echo ${res} | grep -ozP "throughput(\n|.)*?\K(\d+\.\d+)"`
    avg_latency=`echo ${res} | grep -ozP "AVG(\n|.)*?\K(\d+\.\d+)"`
    echo "throughput: " ${throughput} "average latency: " ${avg_latency}
    echo -n "${avg_latency}, " >> ${ep_wl}
    echo -n "${throughput}, " >> ${ep_wt}
}


testTestModeThroughputLatency() {
    cd ${benchmark_bin_path}
    res=`./benchmark.sh`
    throughput=`echo ${res} | grep -ozP "TIME_RANGE\s+\d+\s+.*?\K(\d+\.\d+)"`
    avg_latency=`echo ${res} | grep -ozP "TIME_RANGE\s*?\K(\d+\.\d+)"`
    echo "throughput: " ${throughput} "average latency: " ${avg_latency}
    echo -n "${avg_latency}, " >> ${ep_ql}
    echo -n "${throughput}, " >> ${ep_qt}
}


# modify IotDB server configuration
#   $1: encoding
#   $2: compression
modifyIotDBServerConfig() {
    cd ${iotdb_server_conf_path}
    sed -i -e "665c default_float_encoding=$1" \
        -e "714c compressor=$2" ${iotdb_conf_file}
    printf "Current encoding = $1, compression = $2\n"
}


startIoTDBServer() {
    cd ${iotdb_server_bin_path}
    if [ server_pid != -1 ]; then
        kill -9 ${server_pid}
    fi
    server_pid=`nohup ./start-server.sh > /dev/null 2>&1 & | grep -oP "\s\K\d+"`
}


# $1: encoding
# $2: compression
initResCSVFile() { 
    cd ${res_dir}
    ep_wt="${res_dir}/${ep_wt}"
    ep_wl="${res_dir}/${ep_wl}"
    ep_qt="${res_dir}/${ep_qt}"
    ep_ql="${res_dir}/${ep_ql}"

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

    printf "\nWrite Throughput ($1_$2), " >> ${ep_wt}
    printf "\nWrite Latency ($1_$2), " >> ${ep_wl}
    printf "\nQuery Throughput ($1_$2), " >> ${ep_qt}
    printf "\nQuery Latency ($1_$2), " >> ${ep_ql}
}


testExceptionProportion() {
    echo "Begin test of exception proportion impact"
    for e in ${encoding[@]}
    do
        for c in ${compression[@]}
        do
            modifyIotDBServerConfig ${e} ${c}
            startIoTDBServer
            initResCSVFile ${e} ${c}

            for p in ${exception_proportion[@]}
            do
                cleanDataDir
                genData ${p}
                toggleWriteMode
                echo "Begin write mode with exception proportion = ${p}"
                testWriteModeThroughputLatency ${res_dir} ${ep_wl} ${ep_wt}
                toggleTestMode
                echo "Begin test mode with exception proportion = ${p}"
                testTestModeThroughputLatency ${res_dir} ${ep_ql} ${ep_qt}
            done
        done
    done
}


server_pid=-1  #  pid of iotdb server
testExceptionProportion