import os
import random
import sys
import numpy as np
import pandas as pd
import argparse as ap
import multiprocessing
import matplotlib.pyplot as plt

from datetime import datetime


OFFSET = 2
AMPLITUDE = 10
# process numbers
NUM_PROCESS = 8
# stored in multiple files
# ROWS_TOTAL = 1e8
# ROWS_PER_FILE = 100000
# PERIOD = 10000
ROWS_TOTAL = 7384000
ROWS_PER_FILE = 7384
PERIOD = 7384

FILES_TOTAL = int(ROWS_TOTAL / ROWS_PER_FILE)
FILES_PER_PROCESS = int(FILES_TOTAL / NUM_PROCESS)

# default exception PROPORTIONS
EXCEPTION_PROPORTION = 0.1
# default exception size factor (exception size: [norm_val / factor, norm_val * factor])
EXCEPTION_FACTOR = 2
# default period factor
PERIOD_FACTOR = 1


args = []


def arg_parse():
    global args

    parser = ap.ArgumentParser()
    parser.add_argument(
        '-p',
        '--prefix',
        required=True,
        dest='prefix',
        help='output file name prefix'
    )
    parser.add_argument(
        '-o',
        '--output',
        required=True,
        dest='output',
        help='output directory'
    )
    parser.add_argument(
        '-n', 
        '--exception-proportion',
        required=False,
        dest='proportion',
        type=float,
        help='exception proportion'
    )
    parser.add_argument(
        '-f',
        '--exception-factor',
        required=False,
        dest='factor',
        type=int,
        help='exception factor (exception range: [norm_val / factor, norm_val * factor])'
    )
    parser.add_argument(
        '-c',
        '--period',
        required=False,
        dest='period',
        type=int,
        help='data period'
    )
    parser.add_argument(
        '-i',
        '--input',
        required=False,
        dest='input',
        help='input data file'
    )
    args = parser.parse_args()
    

def genException(y):
    factor = args.factor if args.factor else EXCEPTION_FACTOR
    proportion = args.proportion if args.proportion else EXCEPTION_PROPORTION

    # indices of generated abnormal data
    indices = random.sample(range(1, len(y)), int(proportion * len(y)))
    for i in indices:
        rand = random.uniform(1, factor)
        y[i] *= rand
        

def generate(idx, y):
    global args

    # three columns: timestamps, values (y), labels
    labels = np.array([0] * ROWS_PER_FILE)
    values = np.tile(y, ROWS_PER_FILE // PERIOD)
    prefix = args.prefix

    period = 1000 if not args.period else args.period * 1000
    global_start_time = int(datetime(2000, 1, 1, 0).timestamp() * 1000)
    local_start_time = global_start_time + idx * FILES_PER_PROCESS * ROWS_PER_FILE * period

    filenums = FILES_PER_PROCESS
    if idx == NUM_PROCESS - 1 and FILES_TOTAL / NUM_PROCESS:
        filenums = FILES_PER_PROCESS + FILES_TOTAL % NUM_PROCESS
        
    for i in range(filenums):
        timestamps = [local_start_time + (j + i * ROWS_PER_FILE) * period for j in range(ROWS_PER_FILE)]

        df = pd.DataFrame({
            'Sensor': timestamps,
            's_0': values,
            's_1': labels
        })

        filename = '{}_{}.txt'.format(args.output + prefix, idx * FILES_PER_PROCESS + i)
        df.to_csv(filename, index=False, sep=' ')
        # print('Process {}: file {} generated.'.format(os.getpid(), filename))


def read_y_from_file():
    filename = args.input
    df = pd.read_csv(filename, encoding='utf-8')
    return df['value'].to_numpy()


def gen_sin_wave():
    x = np.arange(PERIOD).astype(float)
    y = AMPLITUDE * np.sin(2 * np.pi * x / PERIOD) + OFFSET
    return y

def main():
    global args
    arg_parse()

    if args.input:
        y = read_y_from_file()
    else:
        y = gen_sin_wave()

    if args.proportion or args.factor:
        genException(y)
    # accurate to three decimal places
    y = np.around(y, decimals=3)

    pool = multiprocessing.Pool(NUM_PROCESS)

    start = datetime.now().timestamp()
    for i in range(NUM_PROCESS):
        pool.apply_async(generate, args=(i, y))

    pool.close()
    pool.join()
    end = datetime.now().timestamp()

    gen_file_nums = os.popen('ls -l {} | grep ^- | wc -l'.format(args.output))
    print('{} data files generated,  time usage: {:.3}s'.format(gen_file_nums.read().rstrip('\n'), end - start))


main()
