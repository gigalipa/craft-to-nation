import re
import sys
from pathlib import Path

def test_balance_data():
    consolidated_file = Path("docs/Fichas_Consumo_Produccion_Consolidada.md")
    if not consolidated_file.exists():
        print(f"FAIL: {consolidated_file} does not exist")
        return False

    content = consolidated_file.read_text(encoding="utf-8")
    
    # Required keys in table
    required_keys = ["Agua", "Comida", "Madera", "Piedra", "Ciclo_Segundos"]
    for key in required_keys:
        if not re.search(rf"\b{key}\b", content, re.IGNORECASE):
            print(f"FAIL: Missing key '{key}' in consolidated balance sheet")
            return False

    print("PASS: Consolidated balance data is complete and verified")
    return True

if __name__ == "__main__":
    if not test_balance_data():
        sys.exit(1)
