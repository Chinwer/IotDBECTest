iotdb_server_bin_path="/home/lulu/projects/iotdb/server/target/iotdb-server-0.13.0-SNAPSHOT/sbin"

gen_data_path="/home/lulu/Downloads/dataset/"

benchmark_bin_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/"
benchmark_data_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/dataset/exception/d_0"
benchmark_config_path="/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/conf"

config_file="config.properties"

# result directory
res_dir="/home/lulu/Downloads/dataset/"

################################
# impact of exception proportion
################################
# impact of exception proportion on write latency
ep_wl=${res_dir}"ep_wl.csv"
# impact of exception proportion on write throughput
ep_wt=${res_dir}"ep_wt.csv"
# impact of exception proportion on query latency
ep_ql=${res_dir}"ep_ql.csv"
# impact of exception proportion on query throughput
ep_qt=${res_dir}"ep_qt.csv"


##########################
# impact of exception size
##########################
# impact of exception size on write latency
es_wl=${res_dir}"es_wl.csv"
# impact of exception size on write throughput
es_wt=${res_dir}"es_wt.csv"
# impact of exception size on query latency
es_ql=${res_dir}"es_wl.csv"
# impact of exception size on query throughput
es_qt=${res_dir}"es_wt.csv"


period=(1 2 3 4 5 6 7 8 9 10)
exception_size=(1 2 3 4 5 6 7 8 9 10)
exception_proportion=(0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9)


cleanDataDir() {
    cd ${benchmark_data_path}
    rm *.txt
}

startIoTDBServer() {
    cd ${iotdb_server_bin_path}
    ./start-server.sh > /dev/null 2>&1 &
}
 

toggleWriteMode() {
    cd ${benchmark_config_path}
    sed -i -e '49c # BENCHMARK_WORK_MODE=testWithDefaultPath' \
        -e '50c BENCHMARK_WORK_MODE=verificationWriteMode' ${config_file}
}


toggleTestMode () {
    cd ${benchmark_config_path}
    sed -i -e '49c BENCHMARK_WORK_MODE=testWithDefaultPath' \
        -e '50c # BENCHMARK_WORK_MODE=verificationWriteMode' ${config_file}
}


testWriteModeThroughputLatency() {
    cd ${benchmark_bin_path}
    res=`./benchmark.sh`
    throughput=`echo ${res} | grep -ozP "throughput(\n|.)*?\K(\d+\.\d+)"`
    avg_latency=`echo ${res} | grep -ozP "AVG(\n|.)*?\K(\d+\.\d+)"`
    # echo "throughput: " ${throughput} "average latency: " ${avg_latency}
    echo ${latency} >> "$1 "
    echo ${throughput} >> "$2 "
}

testTestModeThroughputLatency() {
    cd ${benchmark_bin_path}
    res=`./benchmark.sh`
    throughput=`echo ${res} | grep -ozP "TIME_RANGE.*?\K(\d+\.\d+)"`
    avg_latency=`echo ${res} | grep -ozP "AVG(.|\n)*TIME_RANGE.*?\K(\d+\.\d+)"`
    # echo "throughput: " ${throughput} "average latency: " ${avg_latency}
    echo ${latency} >> "$1 "
    echo ${throughput} >> "$2 "
}


testExceptionProportion() {
    echo "Begin test of exception proportion impact"
    cd ${gen_data_path}
    for p in ${exception_proportion}
    do
        cleanDataDir
        python gen.py -p batch -n ${p}
        toggleWriteMode
        echo "Begin write mode with exception proportion = ${p}"
        testWriteModeThroughputLatency ${ep_wl} ${ep_wt}
        echo "Write mode finished"
        toggleTestMode
        echo "Begin test mode with exception proportion = ${p}"
        testTestModeThroughputLatency ${ep_ql} ${ep_qt}
        echo "Test mode finished"
    done
}

# startIoTDBServer

echo "0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9" >> ${ep_wl}
echo "0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9" >> ${ep_wt}
testExceptionProportion