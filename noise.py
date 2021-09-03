import os
import sys
import random
import pandas as pd

output_dir = '/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/data/noise/d_0/'

filename = sys.argv[1]
mu = float(sys.argv[2])
sigma = float(sys.argv[3])
output_file = sys.argv[4]

if not os.path.exists(output_dir):
    os.mkdir(output_dir)

rows = pd.read_csv(filename, encoding='utf-8')

field = 'value'
# TODO: Gause Noise
for i in range(1, len(rows)):
    rows.loc[i, field] = float(rows.loc[i, field]) + random.gauss(mu, sigma)

rows.columns = ['Sensor', 's_0', 's_1']
rows.to_csv(output_dir + output_file, index=False, encoding='utf-8', sep=' ')