import csv

import matplotlib.pyplot as plt

# Define the file paths for the baseline and scenario CSV files
# baseline_csv = 'iperf3-results-base-client-to-web.csv'
# scenario_csv = 'iperf3-results-client-to-web.csv'

baseline_csv = "iperf3-results-base-inference-to-mq.csv"
scenario_csv = "iperf3-results-inference-to-mq.csv"


def get_average_bitrates(csv_file):
    """Extract average sender and receiver bitrates from the specified CSV file."""
    with open(csv_file) as file:
        reader = csv.DictReader(file)
        for row in reader:
            if row["Timestamp"] == "Average":
                sender_bitrate = float(row["Sender Bitrate (Mbits/sec)"])
                receiver_bitrate = float(row["Receiver Bitrate (Mbits/sec)"])
                return sender_bitrate, receiver_bitrate
    return None, None


# Get the average bitrates for each scenario
baseline_sender, baseline_receiver = get_average_bitrates(baseline_csv)
scenario_sender, scenario_receiver = get_average_bitrates(scenario_csv)

# Check that we retrieved valid data
if baseline_sender is None or scenario_sender is None:
    print("Error: Could not retrieve average bitrates from one or both files.")
    exit()

# Define labels and values for the plot
labels = ["Sender Bitrates", "Receiver Bitrates"]
baseline_values = [baseline_sender, baseline_receiver]
scenario_values = [scenario_sender, scenario_receiver]

# Plotting
x = range(len(labels))  # X-axis positions for labels
width = 0.35  # Width of the bars

fig, ax = plt.subplots()
# Plot baseline and scenario bars side-by-side
bars1 = ax.bar(
    [p - width / 2 for p in x], baseline_values, width=width, label="Baseline"
)
bars2 = ax.bar(
    [p + width / 2 for p in x], scenario_values, width=width, label="Scenario 2"
)

# Labeling
# ax.set_xlabel('Bitrate Type')
ax.set_ylabel("Bitrate (Mbits/sec)")
ax.set_title(
    "Comparison of Average Sender and Receiver Bitrates for Edge 1 to Edge 2 Layers Traffic"
)
ax.set_xticks(x)
ax.set_xticklabels(labels)
ax.set_ylim(0, 110)
ax.legend()

# Add value labels on top of the bars
for bar in bars1:
    height = bar.get_height()
    ax.text(
        bar.get_x() + bar.get_width() / 2.0,
        height,
        f"{height:.2f}",
        ha="center",
        va="bottom",
    )

for bar in bars2:
    height = bar.get_height()
    ax.text(
        bar.get_x() + bar.get_width() / 2.0,
        height,
        f"{height:.2f}",
        ha="center",
        va="bottom",
    )

# Show the plot
plt.show()
