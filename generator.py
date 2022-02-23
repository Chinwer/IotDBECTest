import os
import numpy as np
import pandas as pd

from enum import Enum
from datetime import datetime


class BaseGenerator:
    """
    Attributes:
    interval:
        Timestamp interval between two data points (in ms).
    start_time:
        Starting timestamp.
    """

    def __init__(self, interval: int, start_time: datetime):
        self.interval = interval
        self.start_time = start_time.timestamp()


class RealDatasetSplicer(BaseGenerator):
    """
    Attributes:
    input_file:
        Original real-world dataset file (csv file).
    num:
        Number of times the original data is repeated.
    mode:
        Mode of data splicing.
    output_dir:
        Directory where the spliced data is stored.
    orig_len:
        Length of the original data.
    values:
        Data values.
    labels:
        Indicating whether a data point is anomalous.
    timestamps:
        Data timestamps.
    """

    class SpliceMode(Enum):
        REPEAT = 1  # simply repeat the original data
        MONOTONOUS = 2  # splice data in a monotonously fashion
    
    def __init__(
        self, input_file: str, num: int, output_dir: str,
        mode=SpliceMode.MONOTONOUS, interval=1000,
        start_time=datetime(2019, 1, 1), 
    ):
        super().__init__(interval, start_time)
        
        self.input_file = input_file
        self.num = num
        self.mode = mode
        self.output_dir = output_dir

        self.orig_len = 0
        self.labels = pd.Series(dtype=float)
        self.values = pd.Series(dtype=float)
        self.timestamps = pd.Series(dtype=int)

        self.init_values_labels()
        self.init_timestamps()

    def init_values_labels(self):
        df = pd.read_csv(self.input_file)
        mean = np.mean(df.value)
        self.values = df.value.copy()
        self.orig_len = df.size

        for _ in range(self.num):
            white_noise = np.random.standard_normal(df.size)
            delta = 0
            if self.mode == self.SpliceMode.MONOTONOUS:
                delta = df.value.iloc[-1] - df.value[0]

            tmp = df.value + delta
            tmp += pd.Series(mean / 10 * white_noise)
            self.values = pd.concat(
                [self.values, tmp]
            )

        self.labels = np.zeros(self.values.size)
    
    def init_timestamps(self):
        size = self.values.size
        end_time = self.start_time + self.interval * (size - 1)
        self.timestamps = pd.Series(
            np.linspace(self.start_time, end_time, size, dtype=int)
        )

    def check_output_dir(self):
        """Create the output directory if not existed"""
        if not os.path.exists(self.output_dir):
            os.mkdir(self.output_dir)
        
    def save_to_txt(self, file_num: int):
        """Save df to txt files.

        Args:
        file_num: Number of txt files.

        Raises:
        Exception: when file_num > self.num
        """

        if file_num > self.num:
            raise Exception
        
        self.check_output_dir()

        # fragment: one "copy" of the original data
        nums_per_file = self.num // file_num  # number of fragments per file
        # number of fragments in the last file
        last_nums = nums_per_file + self.num % file_num
        
        for i in range(file_num):
            filename = '{}/batch_{}.txt'.format(self.output_dir, i)
            nums = nums_per_file if i != file_num - 1 else last_nums

            start = i * nums_per_file * self.orig_len
            end = start + nums * self.orig_len
            timestamps_frag = self.timestamps[start:end]
            values_frag = self.values[start:end]
            labels_frag = self.labels[start:end]
            df = pd.DataFrame({
                'Sensor': timestamps_frag,
                's_0': values_frag,
                's_1': labels_frag
            })

            df.to_csv(filename, index=False, sep=' ')
            

def main():
    RealDatasetSplicer(
        input_file='./cloud_data/origin/line_59/liantong_data_from2018-12-19to2019-01-31_8172.csv',
        num=4000,
        output_dir='./res_line/'
    ).save_to_txt(100)


if __name__ == '__main__':
    main()