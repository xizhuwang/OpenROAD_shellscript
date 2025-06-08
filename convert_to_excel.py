#!/usr/bin/env python3
import pandas as pd
import sys

def convert_to_excel(input_file, output_file):
    data = []
    with open(input_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            # 以 "/" 作為分隔符
            parts = line.split("/")
            if len(parts) == 3:
                folder, area, slack = parts
                try:
                    area_val = float(area)
                except ValueError:
                    area_val = None
                try:
                    slack_val = float(slack)
                except ValueError:
                    slack_val = None
                data.append({
                    "Folder": folder,
                    "ChipArea": area_val,
                    "Slack": slack_val
                })
            else:
                print(f"警告：無法解析該行：{line}")
    # 建立 DataFrame 並輸出 Excel
    df = pd.DataFrame(data)
    df.to_excel(output_file, index=False)
    print(f"轉換完成，Excel 檔案儲存為：{output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python convert_to_excel.py input.txt output.xlsx")
        sys.exit(1)
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    convert_to_excel(input_file, output_file)
