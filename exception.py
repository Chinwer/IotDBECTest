import pandas as pd
import random
import sys
import os

output_dir = '/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/data/exception/d_0/'

filename = sys.argv[1]
resultfile = sys.argv[2]
_max = float(sys.argv[3])
_min = float(sys.argv[4])
rand_portion = float(sys.argv[5])

if not os.path.exists(output_dir):
    os.mkdir(output_dir)

data = pd.read_csv(filename, encoding='utf-8')

ab_index = random.sample(range(1, len(data)), int(rand_portion * len(data)))
ab_values = set()
for index in ab_index:
    data.loc[index, 'label'] = 1
    r = random.uniform(_min, 1) if random.random() >= 0.5 else random.uniform(1, _max)
    data.loc[index, 'value'] = int(r * data.loc[index, 'value'])
    # ab_values.add(data.loc[index, 'value'])
    ab_values.add(r)

data.columns = ['Sensor', 's_0', 's_1']
data.to_csv(output_dir + resultfile, index=False, encoding='utf-8', sep=' ')