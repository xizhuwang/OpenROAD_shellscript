#!/bin/bash
# run_tasks.sh
# 此腳本會依序處理使用者從 folder_list.txt 指定的多個資料夾，
# 每個資料夾中必須包含所需的 .v 檔案，
# 複製到指定目的資料夾後執行 make clean_all 與 make，
# 從報告檔中解析數值（synth_stat.txt 中提取晶片面積、6_finish.rpt 中提取 critical path slack），
# 並將結果以「資料夾名稱/晶片面積/slack」格式記錄到 score.txt，
# 最後清除目標資料夾中的複製檔案，並處理下一個資料夾。

# 設定 folder_list.txt 路徑 (此檔案應存放在 $HOME 下)
folder_list_file="$HOME/folder_list.txt"

if [ ! -f "$folder_list_file" ]; then
    echo "找不到 $folder_list_file 檔案，請先建立此檔案並輸入需要處理的資料夾名稱，每行一個。"
    exit 1
fi

# 讀取 folder_list.txt 的內容到陣列（去除行尾換行符號）
readarray -t folder_list < "$folder_list_file"

# 設定相關路徑
score_file="$HOME/score.txt"
dest="$HOME/OpenROAD-flow-scripts/flow/designs/nangate45/FinalCPU"
flow_dir="$HOME/OpenROAD-flow-scripts/flow"
report_dir="$flow_dir/reports/nangate45/FinalCPU/base"

# 清空 score.txt（若不存在則建立）
> "$score_file"

for folder in "${folder_list[@]}"; do
    # 對資料夾名稱進行 trim，移除前後空白及 CR 字符
    folder=$(echo "$folder" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
    
    # 資料夾位於 ~/Assignments3 下，並假設子目錄 Part3 包含 .v 檔案
    folder_path="$HOME/Assignments4/$folder/Part3"
    memory_path="$HOME/Assignments4/memory"   
    
    if [ ! -d "$folder_path" ]; then
        echo "資料夾 $folder_path 不存在，跳過..."
        continue
    fi

    echo "正在處理 $folder ..."

    # 1. 複製所有 .v 檔案到目的資料夾
    cp "$folder_path"/*.v "$dest/"
    rm -f "$dest"/IM.v
    rm -f "$dest"/DM.v
    rm -f "$dest"/RF.v
    cp "$memory_path"/*.v "$dest/"
    # 2. 進入 flow 目錄執行 make clean_all 與 make
    cd "$flow_dir" || { echo "無法進入 $flow_dir"; exit 1; }
    make clean_all
    make

    # 3. 進入報告目錄
    cd "$report_dir" || { echo "無法進入 $report_dir"; exit 1; }

    # 4. 從 synth_stat.txt 中提取晶片面積
    chip_area=$(python3 - <<'EOF'
import re
chip_area = None
with open("synth_stat.txt") as f:
    for line in f:
        if "Chip area for" in line:
            # 匹配 "Chip area for top module '\FinalCPU': ..." 或 "Chip area for module 'FinalCPU': ..." 等格式
            m = re.search(r"Chip area for (?:top )?module '\\?FinalCPU':\s*([\d\.]+)", line)
            if m:
                chip_area = m.group(1)
    if chip_area:
        print(chip_area)
EOF
)

    # 5. 從 6_finish.rpt 中提取 critical path slack
    slack=$(python3 - <<'EOF'
import re
with open("6_finish.rpt") as f:
    text = f.read()
# 使用 DOTALL 模式匹配，提取 finish critical path slack 後面的數值
m = re.search(r"finish critical path slack\s*\n[-]+\n\s*([\d\.\-e+]+)", text, re.DOTALL)
if m:
    print(m.group(1))
EOF
)

    if [ -z "$chip_area" ] || [ -z "$slack" ]; then
        echo "無法從 $folder 擷取數值，跳過此資料夾..."
    else
        # 6. 寫入結果到 score.txt (格式: 資料夾名稱/晶片面積/slack)
        echo "$folder/$chip_area/$slack" >> "$score_file"
    fi

    # 7. 刪除目的資料夾內先前複製的 .v 檔案
    rm -f "$dest"/*.v
done

echo "所有資料夾處理完畢，請檢查 $score_file 內容。"
