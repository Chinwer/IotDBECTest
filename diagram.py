import csv
import sys
import time
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

filename = sys.argv[1]

with open(filename) as f:
    reader = csv.reader(f)
    _ = next(reader)

    i = 1
    dates, values = [], []
    for row in reader:
        time_array = time.localtime(float(row[0]) / 1000)
        date = time.strftime(r'%Y-%m-%d', time_array)
        dates.append(row[0])
        i += 1
        values.append(float(row[1]))


plt.plot(dates, values)
plt.gca().xaxis.set_major_locator(ticker.MultipleLocator(reader.line_num / 9))
plt.show()