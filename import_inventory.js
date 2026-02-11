const admin = require('firebase-admin');
const XLSX = require('xlsx');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Category classification rules
const foodKeywords = ['meat', 'cheese', 'egg', 'rice', 'beans', 'tortilla', 'sauce', 'seasoning', 'butter', 'sour cream', 'produce', 'salsa'];
const serviceKeywords = ['cup', 'lid', 'napkin', 'bag', 'tray', 'straw', 'fork', 'spoon', 'plate', 'bowl'];
const equipmentKeywords = ['shaker', 'rack', 'scooper', 'dispenser', 'warmer', 'pan', 'container', 'bin', 'cooler'];

function classifyCategory(itemName) {
  const name = itemName.toLowerCase();
  
  // Check food keywords
  for (const keyword of foodKeywords) {
    if (name.includes(keyword)) {
      return 'food';
    }
  }
  
  // Check service keywords
  for (const keyword of serviceKeywords) {
    if (name.includes(keyword)) {
      return 'service';
    }
  }
  
  // Check equipment keywords
  for (const keyword of equipmentKeywords) {
    if (name.includes(keyword)) {
      return 'equipment';
    }
  }
  
  // Default to food if uncertain
  return 'food';
}

function extractUnitType(notes) {
  if (!notes || typeof notes !== 'string') return '';
  
  // Common unit patterns
  const unitPatterns = [
    /(\d+)\s*(?:oz|ounce)s?/i,
    /(\d+)\s*(?:lb|pound)s?/i,
    /(\d+)\s*(?:g|gram)s?/i,
    /(\d+)\s*(?:kg|kilogram)s?/i,
    /(\d+)\s*(?:ct|count)/i,
    /(\d+)\s*(?:pk|pack)/i,
    /(\d+)\s*(?:box|boxes)/i,
    /(\d+)\s*(?:bag|bags)/i,
    /(\d+)\s*(?:case|cases)/i,
    /(\d+)\s*(?:bottle|bottles)/i,
    /(\d+)\s*(?:jar|jars)/i,
    /(\d+)\s*(?:can|cans)/i,
    /(\d+)\s*(?:gal|gallon)s?/i,
    /(\d+)\s*(?:qt|quart)s?/i,
    /(\d+)\s*(?:pt|pint)s?/i
  ];
  
  for (const pattern of unitPatterns) {
    const match = notes.match(pattern);
    if (match) {
      return match[0];
    }
  }
  
  // Look for unit words without numbers
  if (notes.match(/box|bag|pack|case|bottle|jar|can|gallon|quart|pint|pound|ounce|gram/i)) {
    const unitMatch = notes.match(/(box|bag|pack|case|bottle|jar|can|gallon|quart|pint|pound|ounce|gram)s?/i);
    if (unitMatch) {
      return unitMatch[0];
    }
  }
  
  return '';
}

async function importInventory() {
  try {
    console.log('Starting inventory import...');
    
    // Load Excel file
    const workbook = XLSX.readFile('Actual_Truck_Inventory_From_List.xlsx');
    const sheetName = 'MASTER INVENTORY';
    
    if (!workbook.Sheets[sheetName]) {
      console.error(`Sheet '${sheetName}' not found in Excel file`);
      return;
    }
    
    const worksheet = workbook.Sheets[sheetName];
    const data = XLSX.utils.sheet_to_json(worksheet);
    
    console.log(`Total rows parsed: ${data.length}`);
    
    // Get existing items to check for duplicates
    const existingItemsSnapshot = await db.collection('items').get();
    const existingItemNames = new Set();
    existingItemsSnapshot.forEach(doc => {
      existingItemNames.add(doc.data().name.toLowerCase());
    });
    
    console.log(`Existing items in database: ${existingItemNames.size}`);
    
    let inserted = 0;
    let skipped = 0;
    const batchSize = 500;
    let batch = db.batch();
    let batchCount = 0;
    
    for (const row of data) {
      const itemName = row['Item Name'] || row['Item'] || row['name'] || '';
      
      if (!itemName) {
        console.log('Skipping row with no item name');
        skipped++;
        continue;
      }
      
      // Check for duplicate (case-insensitive)
      if (existingItemNames.has(itemName.toLowerCase())) {
        console.log(`Skipping duplicate: ${itemName}`);
        skipped++;
        continue;
      }
      
      // Extract and classify data
      const category = classifyCategory(itemName);
      const unitType = extractUnitType(row['Notes / Pack / Description'] || row['Notes'] || row['Description'] || '');
      
      const itemData = {
        name: itemName,
        category: category,
        unitType: unitType,
        model: '',
        qtyPerService: 1,
        truckAmount: parseFloat(row['In Truck']) || 0,
        homeAmount: parseFloat(row['In Home']) || 0,
        gettingLow: 0,
        needToPurchase: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: 'ai-import'
      };
      
      // Add to batch
      const docRef = db.collection('items').doc();
      batch.set(docRef, itemData);
      batchCount++;
      
      // Commit batch when it reaches 500 items
      if (batchCount >= batchSize) {
        await batch.commit();
        console.log(`Committed batch of ${batchCount} items`);
        batch = db.batch();
        batchCount = 0;
        inserted += batchSize;
      }
      
      existingItemNames.add(itemName.toLowerCase());
    }
    
    // Commit remaining items in batch
    if (batchCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${batchCount} items`);
      inserted += batchCount;
    }
    
    console.log('\n=== IMPORT SUMMARY ===');
    console.log(`Total rows parsed: ${data.length}`);
    console.log(`Total inserted: ${inserted}`);
    console.log(`Total skipped (duplicates): ${skipped}`);
    console.log('Import completed successfully!');
    
  } catch (error) {
    console.error('Import failed:', error);
  } finally {
    process.exit(0);
  }
}

// Run the import
importInventory();
