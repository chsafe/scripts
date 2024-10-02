import base64
import requests
import json
import sys
import urllib.parse
import subprocess
import os

def get_country_info(country_code, country_data):
    for country in country_data:
        if country['abbreviate'].lower() == country_code.lower():
            return country
    return None

def process_ss_link(line, country_data):
    parts = line.strip().split('#', 1)
    if len(parts) != 2:
        return line.strip()

    ss_link, country_code = parts
    country_info = get_country_info(country_code, country_data)

    if not country_info:
        print(f"无法找到国家信息: {country_code}", file=sys.stderr)
        return line.strip()

    suffix = {
        "name": {
            "zh-Hans": country_info['name'],
            "en": country_info['enName']
        },
        "type": "free",
        "country": country_info['abbreviate'],
        "ping": "www.baidu.com" if country_info['abbreviate'].lower() == "cn" else "www.google.com",
        "ipv6": False
    }

    return f"{ss_link}#{country_code}#{json.dumps(suffix, ensure_ascii=False)}"

def main():
    # Step 1: Access the URL and get the content
    url = "http://x.rushvpn.win:7001/api/v1/client/subscribe?token=49b4c85a7793b4f3728b84f753d280e8"
    response = requests.get(url)

    if response.status_code != 200:
        print(f"Failed to access URL. Status code: {response.status_code}")
        exit()

    base64_content = response.text
    print("URL accessed successfully. Content received.")

    # Step 2: Decode Base64 content
    try:
        decoded_data = base64.b64decode(base64_content).decode('utf-8')
        print("Base64 decoding successful.")
    except Exception as e:
        print(f"Failed to decode Base64 content: {e}")
        exit()

    # Step 3: Download CountryCode.json file
    country_code_url = "https://raw.githubusercontent.com/chsafe/scripts/refs/heads/main/CountryCode.json"
    country_data_response = requests.get(country_code_url)
    country_data = country_data_response.json()

    # Step 4: Process each SS link
    processed_links = []
    for line in decoded_data.splitlines():
        processed_line = process_ss_link(line, country_data)
        processed_links.append(processed_line)

    # Step 5: Join processed links
    processed_content = '\n'.join(processed_links)

    # Step 6: Save the results to aaaa file
    with open("aaaa", "w", encoding="utf-8") as file:
        file.write(processed_content)

    print("Processing complete. Results saved to 'aaaa'.")

    # Step 7: Execute encodeconfig.exe
    try:
        result = subprocess.run(['C:/Users/36850/Desktop/homevpn/encodeconfig.exe', 'aaaa', 'C:/Users/36850/Desktop/homevpn/homevpn/connect'], check=True, capture_output=True, text=True)
        print("encodeconfig.exe executed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error executing encodeconfig.exe: {e}")
        print("Error Output:", e.stderr)

    # Step 8: Print content of connect.txt file
    connect_file = "C:/Users/36850/Desktop/homevpn/homevpn/connect.txt"
    try:
        with open(connect_file, 'r', encoding='utf-8') as file:
            print(f"\nContents of {connect_file}:")
            print(file.read())
    except IOError as e:
        print(f"Error reading {connect_file}: {e.strerror}")

    # Step 9: Delete connect.txt file
    try:
        os.remove(connect_file)
        print(f"\nSuccessfully deleted {connect_file}")
    except OSError as e:
        print(f"Error deleting {connect_file}: {e.strerror}")

if __name__ == "__main__":
    main()