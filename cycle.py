from io import FileIO
import os
import sys
import pandas as pd

output_dir = '/home/lulu/projects/iotdb-benchmark/iotdb-0.12/target/iotdb-0.12-0.0.1/data/cycle/d_0/'

filename = sys.argv[1]
multi = float(sys.argv[2])
output_file = sys.argv[3]

if not os.path.exists(output_dir):
    os.mkdir(output_dir)

rows = pd.read_csv(filename, encoding='utf-8')

field = 'timestamp'
interval = float(rows.loc[1, field]) - float(rows.loc[0, field])
new_interval = interval * multi

for i in range(1, len(rows)):
    rows.loc[i, field] = float(rows.loc[i - 1, field]) + new_interval

rows.columns = ['Sensor', 's_0', 's_1']
rows.to_csv(output_dir + output_file, index=False, encoding='utf-8', sep=' ')