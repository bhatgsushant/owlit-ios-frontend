import fileinput
import sys

search_line = "const responsePayload = { ...transformedData };"
insert_code = """
      // Check for duplicate receipt
      if (req.user?.id) {
        const { data: existingReceipt } = await supabase
          .from('receipts')
          .select('id')
          .eq('user_id', req.user.id)
          .eq('merchant_name', transformedData.merchant_name)
          .eq('transaction_date', transformedData.transaction_date)
          .eq('total_amount', transformedData.total_amount)
          .maybeSingle();

        if (existingReceipt) {
          console.log(`⚠️ Duplicate receipt detected! Existing ID: ${existingReceipt.id}`);
          transformedData.id = existingReceipt.id;
        }
      }
"""

file_path = '/Users/sushantbhat/Desktop/owlitiOS/server.js'
modified = False

lines = []
with open(file_path, 'r') as f:
    lines = f.readlines()

with open(file_path, 'w') as f:
    for line in lines:
        if search_line in line and not modified:
            f.write(insert_code + "\n")
            f.write(line)
            modified = True
        else:
            f.write(line)

if modified:
    print("Successfully patched server.js")
else:
    print("Could not find insertion point")
