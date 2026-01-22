import pandas as pd
import json
import os

# ---------------------------------------------------------
# UPDATE THIS TO YOUR ACTUAL EXCEL FILE NAME
excel_filename = 'OLT - ODF PATCHING FOR MIGRATION - LONG LAT.xlsx'
sheet_name = 'TGY001 MIGRATION'  # The tab name at the bottom of Excel
# ---------------------------------------------------------

output_file = 'assets/lcp_data.json'

print(f"--- Reading Excel File: {excel_filename} ---")

try:
    # 1. READ EXCEL DIRECTLY
    # header=1 means Row 2 contains the titles (OLT PORT, LCP Name Tag, etc.)
    df = pd.read_excel(
        excel_filename, 
        sheet_name=sheet_name, 
        header=1, 
        engine='openpyxl'
    )
    
    print(f"Success! Loaded {len(df)} rows from sheet '{sheet_name}'.")
    
    # 2. RENAME COLUMNS (To ensure code consistency)
    # We map the specific column names found in Excel to our internal variables
    # Note: Excel columns might have extra spaces like "NEW  ODF" (two spaces)
    df.columns = df.columns.str.strip()  # Remove spaces from ends
    
    print("Columns found:", list(df.columns))
    
    # Verify strict column existence
    if 'LCP Name Tag' not in df.columns:
        print("CRITICAL: Could not find 'LCP Name Tag' column.")
        # Fallback search if names are slightly different
        for col in df.columns:
            if 'LCP' in col:
                print(f"Did you mean '{col}'?")
        exit()

except Exception as e:
    print(f"Error reading Excel file: {e}")
    print("Make sure the file is in the same folder and the sheet name is correct.")
    exit()

# 3. HELPER FUNCTION
def parse_lat_long(coord_val):
    # Excel might give us a string "14.1, 120.2" OR already give us numbers if formatted that way
    if pd.isna(coord_val): return None
    
    try:
        s = str(coord_val).replace('"', '').replace("'", "").strip()
        parts = s.split(',')
        if len(parts) >= 2:
            return {
                "lat": float(parts[0].strip()),
                "lng": float(parts[1].strip())
            }
    except:
        pass
    return None

# 4. PROCESS DATA
output_list = []
np_cols = ['NP1-2', 'NP3-4', 'NP5-6', 'NP7-8']

# Drop empty rows
clean_df = df.dropna(subset=['LCP Name Tag'])

print(f"Processing {len(clean_df)} valid LCP rows...")

for lcp_name, group in clean_df.groupby('LCP Name Tag'):
    
    # Get Site Name
    site_name = "Unknown"
    if 'SITE NAME' in group.columns:
        valid_sites = group['SITE NAME'].dropna()
        if not valid_sites.empty:
            site_name = str(valid_sites.iloc[0])

    # Determine Status
    # Logic: If 'NEW PORT' is filled, it's migrated.
    total_ports = len(group)
    migrated_count = 0
    
    # Check for 'NEW PORT' (Handle variations like "NEW PORT" or "NEW  PORT")
    new_port_col = next((c for c in group.columns if "NEW" in c and "PORT" in c), None)
    
    if new_port_col:
        migrated_count = group[new_port_col].notna().sum()
    
    if migrated_count == total_ports and total_ports > 0:
        status = "Migrated"
    elif migrated_count == 0:
        status = "Pending"
    else:
        status = "Partially Migrated"
    
    # Extract Coordinates
    unique_nps = {}
    for idx, row in group.iterrows():
        for col_name in np_cols:
            if col_name in row:
                coords = parse_lat_long(row[col_name])
                if coords:
                    key = f"{coords['lat']},{coords['lng']}"
                    if key not in unique_nps:
                        unique_nps[key] = {
                            "name": col_name,
                            "lat": coords['lat'],
                            "lng": coords['lng']
                        }
    
    output_list.append({
        "lcp_name": str(lcp_name).strip(),
        "site_name": site_name.strip(),
        "status": status,
        "nps": list(unique_nps.values())
    })

# 5. SAVE
os.makedirs(os.path.dirname(output_file), exist_ok=True)
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(output_list, f, indent=2, ensure_ascii=False)

print(f"SUCCESS! Processed {len(output_list)} LCPs.")
print(f"Data saved to: {output_file}")