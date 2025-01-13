import os
import subprocess
import csv
import json
from datetime import datetime
import argparse

# File name for the CSV to store results
csv_file = 'iperf3-results-client-to-web.csv'

# IP and port of the server to connect to
server_ip = "ziti.web-server"
port = "5201"

def run_iperf3():
    # Run iperf3 command and capture the output
    command = ["iperf3", "-c", server_ip, "-p", port, "-J", "-t", "20"]
    result = subprocess.run(command, capture_output=True, text=True)

    # Check if the command was successful
    if result.returncode != 0:
        print("iperf3 test failed:", result.stderr)
        return None

    # Parse output to get sender and receiver bitrates using regular expressions
    try:
        output_json = json.loads(result.stdout)
        
        # Retrieve the list of intervals
        intervals = output_json["intervals"]
        
        # Exclude the first streams if its start time is 0
        if intervals and intervals[0]["streams"][0]["start"] == 0:
            first_packet_bitrate = intervals[0]["streams"][0]["bits_per_second"]
            print(f"Excluding first interval with bitrate: {first_packet_bitrate / 1_000_000:.2f} Mbits/sec")
            intervals = intervals[1:]
            print("Length of intervals: ", len(intervals))
        
        # Calculate the average sender bitrate of the remaining intervals
        if intervals:
            total_sender_bitrate = sum(interval["streams"][0]["bits_per_second"] for interval in intervals)
            average_sender_bitrate = total_sender_bitrate / len(intervals) / 1_000_000  # Convert to Mbits/sec
        else:
            average_sender_bitrate = 0
        
        # Calculate the average receiver bitrate of the remaining intervals
        average_receiver_bitrate = output_json["end"]["sum_received"]["bits_per_second"] / 1_000_000  # Convert to Mbits/sec
        
        return average_sender_bitrate, average_receiver_bitrate
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        print(f"Error parsing iperf3 JSON output: {e}")
        return None

def append_to_csv(data):
    # Check if the CSV file exists; if not, create it with a header row
    file_exists = os.path.isfile(csv_file)

    with open(csv_file, mode='a', newline='') as file:
        writer = csv.writer(file)
        if not file_exists:
            writer.writerow(["Timestamp", "Sender Bitrate (Mbits/sec)", "Receiver Bitrate (Mbits/sec)"])
        writer.writerow(data)

def calculate_average_bitrate():
    sender_total, receiver_total = 0, 0
    count = 0

    with open(csv_file, mode='r') as file:
        reader = csv.reader(file)
        next(reader)  # Skip header row
        for row in reader:
            sender_total += float(row[1])
            receiver_total += float(row[2])
            count += 1

    if count > 0:
        avg_sender = sender_total / count
        avg_receiver = receiver_total / count
        print(f"\nAverage Sender Bitrate: {avg_sender:.2f} Mbits/sec")
        print(f"Average Receiver Bitrate: {avg_receiver:.2f} Mbits/sec")

        # Append average to CSV with timestamp "Average"
        append_to_csv(["Average", avg_sender, avg_receiver])
        print("Average results appended to CSV.")
    else:
        print("No data to calculate averages.")

def main(n):
    for i in range(n):
        print(f"Run {i + 1}/{n}")
        results = run_iperf3()
        if results:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            data = [timestamp] + list(results)
            append_to_csv(data)
            print(f"Results appended to {csv_file}: {data}")
        else:
            print("No results to write for this run.")

    # Calculate and display average bitrate
    calculate_average_bitrate()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run iperf3 test multiple times and record results.")
    parser.add_argument("-n", "--num-runs", type=int, default=1, help="Number of times to run the iperf3 test")
    args = parser.parse_args()

    main(args.num_runs)