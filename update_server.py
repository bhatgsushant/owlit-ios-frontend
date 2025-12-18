import re

file_path = '/Users/sushantbhat/Desktop/owlitiOS/server.js'

with open(file_path, 'r') as f:
    content = f.read()

# Pattern to find the end of transformedData definition
pattern = r"(ai_insight:\s*await generateUserInsightFromSupabase.*?\n\s*await generateScanInsight\(\{[\s\S]*?\}\),\s*\n\s*\};)"

replacement = r"""\1

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
      }"""

new_content = re.sub(pattern, replacement, content, count=1)

if new_content != content:
    with open(file_path, 'w') as f:
        f.write(new_content)
    print("Successfully patched server.js")
else:
    print("Could not find insertion point in server.js")
