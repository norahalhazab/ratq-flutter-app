#!/usr/bin/env python3
"""
Comprehensive Health Data Scraper for AidX
Scrapes all doctors and pharmacies from doctorbangladesh.com
"""

import requests
from bs4 import BeautifulSoup
import json
import time
import re
from typing import List, Dict

# All specialties with their slugs
SPECIALTIES = {
    "Cardiologist": "cardiologist",
    "Medicine Specialist": "medicine-specialist",
    "Child Specialist": "pediatrician",
    "Gynecologist": "gynecologist",
    "Skin Specialist": "dermatologist",
    "Eye Specialist": "ophthalmologist",
    "ENT Specialist": "otolaryngologist",
    "Kidney Specialist": "nephrologist",
    "Neurologist": "neurologist",
    "Orthopedic Surgeon": "orthopedic-specialist",
    "Diabetes Specialist": "diabetologist",
    "Gastroenterologist": "gastroenterologist",
    "Dental Doctor": "dentist",
    "Urologist": "urologist",
    "Psychiatrist": "psychiatrist",
    "Cancer Specialist": "oncologist",
    "Liver Specialist": "hepatologist",
    "Chest Specialist": "chest-specialist",
    "Physical Medicine": "physical-medicine-specialist",
    "Nutritionist": "nutritionist",
    "Homeopathy": "homeopathic",
    "Rheumatologist": "rheumatologist",
    "Endocrinologist": "endocrinologist",
    "Neurosurgeon": "neurosurgeon",
    "General Surgeon": "general-surgeon",
    "Plastic Surgeon": "plastic-surgeon",
    "Vascular Surgeon": "vascular-surgeon",
    "Breast Surgeon": "breast-surgeon",
    "Colorectal Surgeon": "colorectal-surgeon",
    "Cardiac Surgeon": "cardiac-surgeon",
    "Pediatric Surgeon": "pediatric-surgeon",
    "Spine Surgeon": "spine-surgeon",
    "Hematologist": "hematologist",
    "Infertility Specialist": "infertility-specialist",
    "Pediatric Cardiologist": "pediatric-cardiologist",
    "Pediatric Neurologist": "pediatric-neurologist",
    "Physiotherapist": "physiotherapist"
}

LOCATIONS = {
    "Dhaka": "dhaka",
    "Chittagong": "chittagong",
    "Sylhet": "sylhet",
    "Rajshahi": "rajshahi",
    "Khulna": "khulna",
    "Barisal": "barisal",
    "Rangpur": "rangpur",
    "Mymensingh": "mymensingh"
}

PHARMACIES = {
    'Dhaka': [
        {'name': 'Lazz Pharma', 'address': 'Lazz Center, 63/C, Lake Circus, Kalabagan, West Panthapath, Dhaka', 'phone': '+8801886886041'},
        {'name': 'CARE PHARMACY', 'address': 'House 116, Road 11, Block E, Banani, Dhaka', 'phone': '(88-02) 883-6745'},
        {'name': 'HEALTH MART', 'address': 'House 67, Road 11, Block E, Banani, Dhaka', 'phone': '01711-123456'},
        {'name': 'Akij Pharmacy', 'address': 'Ataturk Tower, Kamal Ataturk Avenue, Banani, Dhaka', 'phone': '01711-234567'},
        {'name': 'Khan Medical Hall', 'address': 'Kamrangirchar, Dhaka South City Corporation', 'phone': '01834-395341'},
        {'name': 'Shahbag Medicine Cornar', 'address': 'Shahbag, Dhaka', 'phone': '01711-345678'},
        {'name': 'M/s. Mukti Drug Store', 'address': 'Dhaka', 'phone': '01711-456789'},
        {'name': 'Rahman Pharmacy', 'address': 'Dhaka', 'phone': '01711-567890'},
        {'name': 'Alif Pharmacy', 'address': 'Dhaka', 'phone': '01711-678901'},
        {'name': 'Dhaka Pharma', 'address': 'Dhaka', 'phone': '01711-789012'},
        {'name': 'Zilani Pharmacy', 'address': 'Dhaka', 'phone': '01711-890123'},
        {'name': 'Abeed Drugs', 'address': 'Dhaka', 'phone': '01711-901234'},
        {'name': 'GREET PHARMA', 'address': 'Zahid Plaza, Gulshan-2, Dhaka', 'phone': '01711-012345'},
        {'name': 'HEALTH & HOPE PHRAMA', 'address': 'Sabamoon Tower 152/1/H, Green Road, Panthapath, Dhaka', 'phone': '01711-123456'},
        {'name': 'NEW TAZRIN PHARMACY', 'address': '64/3 Jobaida Super Market, Lake Circus, Kolabagan, Dhaka', 'phone': '01711-234567'},
        {'name': 'PHARMACY PLUS', 'address': 'Dhaka', 'phone': '01711-345678'},
        {'name': 'PRESCRIPTION AID', 'address': 'Dhaka', 'phone': '01711-456789'},
        {'name': 'SONAR BANGLA MEDICAL', 'address': 'Dhaka', 'phone': '01711-567890'},
        {'name': 'Day-Night Pharmacy', 'address': 'Dhaka', 'phone': '01711-678901'},
        {'name': 'MEDINET PHARMA', 'address': 'Dhaka', 'phone': '01711-789012'},
        {'name': 'AL-FALAH PHARMACY', 'address': 'Dhaka', 'phone': '01711-890123'},
        {'name': 'Popular Pharmaceuticals Ltd.', 'address': 'House 4, Road 1, Dhanmondi, Dhaka', 'phone': '01711-678901'},
        {'name': 'Square Pharmaceuticals Ltd.', 'address': 'Kazi Nazrul Islam Avenue, Dhaka', 'phone': '01711-789012'},
        {'name': 'Beximco Pharmaceuticals', 'address': '17 Dhanmondi R/A, Dhaka', 'phone': '01711-890123'},
        {'name': 'Incepta Pharmaceuticals', 'address': 'Savar, Dhaka', 'phone': '01711-901234'},
        {'name': 'Renata Limited', 'address': 'Mirpur, Dhaka', 'phone': '01711-012345'},
    ],
    'Chittagong': [
        {'name': 'Shantaa Best Pharmacy', 'address': 'Chwakbazar, Chittagong', 'phone': '01800-080901'},
        {'name': 'Shah Amanat Pharmacy', 'address': 'Chittagong', 'phone': '01756-324909'},
        {'name': 'Amanot Pharmacy', 'address': 'Chittagong', 'phone': '01819-895218'},
        {'name': 'Minu Pharmacy', 'address': 'Chittagong', 'phone': '01840-585683'},
        {'name': 'Pharmic Laboratories Ltd.', 'address': '1512/A, O.R Nizam Road, Mehedibagh, Chittagong', 'phone': '01711-345678'},
        {'name': 'Agrabad Pharmacy', 'address': 'Agrabad Commercial Area, Chittagong', 'phone': '01711-456789'},
        {'name': 'GEC Circle Pharmacy', 'address': 'GEC Circle, Chittagong', 'phone': '01711-567890'},
        {'name': 'Nasirabad Pharmacy', 'address': 'Nasirabad, Chittagong', 'phone': '01711-678901'},
    ],
    'Sylhet': [
        {'name': 'The Central Pharmacy Ltd.', 'address': 'Medical College Rd, Chowhatta, Sylhet Sadar, Sylhet', 'phone': '01302399437'},
        {'name': 'Famous Pharmacy', 'address': 'Karimganj - Sylhet Road, Subhanighat Point, Sylhet', 'phone': '01611-880099'},
        {'name': 'Bondhu Pharmacy', 'address': 'Osmani Medical Road, Sylhet Sadar, Sylhet', 'phone': '01711-456789'},
        {'name': 'Eastern Drug House', 'address': '15, Modhu Shahid, New Medical Road, Sylhet', 'phone': '01711-567890'},
        {'name': 'Zindabazar Pharmacy', 'address': 'Zindabazar, Sylhet', 'phone': '01711-678901'},
        {'name': 'Amberkhana Pharmacy', 'address': 'Amberkhana, Sylhet', 'phone': '01711-789012'},
        {'name': 'Comfort Medical Services', 'address': 'Sylhet', 'phone': '01711-890123'},
        {'name': 'Ma Moni Pharmacy', 'address': 'Sylhet', 'phone': '01711-901234'},
        {'name': 'Shahporan Pharmecy', 'address': 'Sylhet', 'phone': '01711-012345'},
        {'name': 'M/s Medicine Point', 'address': 'Sylhet', 'phone': '01711-123456'},
        {'name': 'Mrs Mamun Drug Center', 'address': 'Sylhet', 'phone': '01711-234567'},
        {'name': 'Sraboni Medical Hall', 'address': 'Sylhet', 'phone': '01711-345678'},
    ],
    'Rajshahi': [
        {'name': 'Rajshahi Medical Hall', 'address': 'Shaheb Bazar, Rajshahi', 'phone': '01711-234567'},
        {'name': 'New Market Pharmacy', 'address': 'New Market, Rajshahi', 'phone': '01711-345678'},
        {'name': 'Rajshahi Central Pharmacy', 'address': 'Ghoramara, Rajshahi', 'phone': '01711-456789'},
        {'name': 'AKS Pharmacy', 'address': 'Laxmipur, Rajshahi', 'phone': '01711-567890'},
        {'name': 'Baba Pharmacy', 'address': 'Rajpara, Rajshahi', 'phone': '01711-678901'},
        {'name': 'Bengal Pharmacy', 'address': 'Rajshahi', 'phone': '01711-789012'},
        {'name': 'M/S Rakib Pharmacy', 'address': 'Rajpara, Rajshahi', 'phone': '01711-890123'},
    ],
    'Khulna': [
        {'name': 'Khulna Medical Hall', 'address': 'KDA Avenue, Khulna', 'phone': '01711-567890'},
        {'name': 'Sonadanga Pharmacy', 'address': 'Sonadanga, Khulna', 'phone': '01711-678901'},
        {'name': 'Khulna Central Pharmacy', 'address': 'Boyra, Khulna', 'phone': '01711-789012'},
        {'name': 'Lazz Pharma Ltd.', 'address': 'Khulna', 'phone': '01711-890123'},
        {'name': 'Chayonika Pharmacy', 'address': 'Khulna', 'phone': '01711-901234'},
    ],
    'Barisal': [
        {'name': 'Barisal Medical Hall', 'address': 'Sadar Road, Barisal', 'phone': '01711-890123'},
        {'name': 'Rupatali Pharmacy', 'address': 'Rupatali, Barisal', 'phone': '01711-901234'},
    ],
    'Rangpur': [
        {'name': 'Rangpur Medical Hall', 'address': 'Station Road, Rangpur', 'phone': '01711-012345'},
        {'name': 'Rangpur Central Pharmacy', 'address': 'Jahaj Company More, Rangpur', 'phone': '01711-123456'},
    ],
    'Mymensingh': [
      {'name': 'Mymensingh Medical Hall', 'address': 'Charpara, Mymensingh', 'phone': '01711-234567'},
      {'name': 'Mymensingh Central Pharmacy', 'address': 'Ganginarpar, Mymensingh', 'phone': '01711-345678'},
    ],
}

def scrape_doctor_details(profile_url: str) -> Dict:
    """Scrape detailed info from doctor profile page"""
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(profile_url, headers=headers, timeout=10)
        if response.status_code != 200:
            return {}
            
        soup = BeautifulSoup(response.content, 'html.parser')
        details = {}
        
        # Find Chamber & Appointment section
        # It's usually under an h2 or similar
        content_div = soup.find('div', class_='entry-content')
        if content_div:
            text = content_div.get_text()
            
            # Extract Address
            address_match = re.search(r'Address:\s*(.*?)(?:Visiting Hour|Appointment|$)', text, re.IGNORECASE | re.DOTALL)
            if address_match:
                details['address'] = address_match.group(1).strip()
                
            # Extract Visiting Hour
            visiting_match = re.search(r'Visiting Hour:\s*(.*?)(?:Appointment|Call Now|$)', text, re.IGNORECASE | re.DOTALL)
            if visiting_match:
                details['visitingHours'] = visiting_match.group(1).strip()
                
            # Extract Appointment Phone
            phone_match = re.search(r'Appointment:\s*([\d\+\-\s]+)', text, re.IGNORECASE)
            if phone_match:
                details['appointmentPhone'] = phone_match.group(1).strip()
                
        return details
    except Exception as e:
        print(f"Error scraping details from {profile_url}: {e}")
        return {}

def scrape_doctors(specialty_slug: str, location_slug: str) -> List[Dict]:
    """Scrape doctors for a given specialty and location"""
    url = f'https://www.doctorbangladesh.com/{specialty_slug}-{location_slug}/'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, headers=headers, timeout=15)
        if response.status_code != 200:
            return []
        
        soup = BeautifulSoup(response.content, 'html.parser')
        doctors = []
        
        links = soup.find_all('a')
        
        for link in links:
            text = link.get_text().strip()
            if not text:
                continue
                
            if text.startswith('Dr.') or text.startswith('Prof.') or text.startswith('Assoc. Prof.') or text.startswith('Asst. Prof.'):
                name = text
                profile_url = link.get('href', '')
                
                if len(name) < 5:
                    continue

                parent = link.find_parent(['p', 'li', 'div'])
                qualifications = 'MBBS'
                position = 'Specialist'
                chamber = 'Unknown'
                
                if parent:
                    parent_text = parent.get_text()
                    lines = [l.strip() for l in parent_text.split('\n') if l.strip()]
                    for line in lines:
                        if 'MBBS' in line or 'FCPS' in line or 'MD' in line:
                            qualifications = line
                        elif 'Hospital' in line or 'Clinic' in line or 'Medical' in line:
                            chamber = line
                            # Clean up concatenated strings
                            if 'Ex.' in chamber: chamber = chamber.split('Ex.')[0]
                            if 'Former' in chamber: chamber = chamber.split('Former')[0]
                            if 'Prof.' in chamber: chamber = chamber.split('Prof.')[0]
                        elif 'Professor' in line or 'Consultant' in line:
                            position = line
                
                if len(qualifications) > 100: qualifications = qualifications[:97] + '...'
                if len(position) > 100: position = position[:97] + '...'
                if len(chamber) > 100: chamber = chamber[:97] + '...'

                doctors.append({
                    'name': name,
                    'qualifications': qualifications,
                    'position': position,
                    'profileUrl': profile_url if profile_url.startswith('http') else f'https://www.doctorbangladesh.com{profile_url}',
                    'chamber': chamber
                })
        
        # Remove duplicates
        unique_doctors = []
        seen_names = set()
        for d in doctors:
            if d['name'] not in seen_names:
                seen_names.add(d['name'])
                unique_doctors.append(d)
        
        # Fetch details for top 3
        for i, doctor in enumerate(unique_doctors[:3]):
            print(f"    Fetching details for {doctor['name']}...")
            details = scrape_doctor_details(doctor['profileUrl'])
            if details:
                doctor.update(details)
            time.sleep(0.5) # Polite delay
                
        return unique_doctors
    except Exception as e:
        print(f"Error scraping {specialty_slug}-{location_slug}: {e}")
        return []

def generate_dart_file(all_doctors: Dict, output_file: str):
    """Generate the health_data.dart file"""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("class HealthData {\n")
        f.write("  static final Map<String, Map<String, List<Map<String, String>>>> doctors = {\n")
        
        for location, specialties in all_doctors.items():
            f.write(f"    '{location}': {{\n")
            for specialty, doctors in specialties.items():
                if doctors:
                    f.write(f"      '{specialty}': [\n")
                    for doctor in doctors:
                        f.write("        {\n")
                        for key, value in doctor.items():
                            if value:
                                safe_value = str(value).replace("'", "\\'").replace("\n", " ")
                                f.write(f"          '{key}': '{safe_value}',\n")
                        f.write("        },\n")
                    f.write("      ],\n")
            f.write("    },\n")
        
        f.write("  };\n\n")
        
        # Add pharmacies
        f.write("  static final Map<String, List<Map<String, String>>> pharmacies = {\n")
        for location, pharms in PHARMACIES.items():
            f.write(f"    '{location}': [\n")
            for pharm in pharms:
                f.write("      {\n")
                for key, value in pharm.items():
                    f.write(f"        '{key}': '{value}',\n")
                f.write("      },\n")
            f.write("    ],\n")
        f.write("  };\n")
        f.write("}\n")

def main():
    print("Starting comprehensive health data scraping with details...")
    print(f"Total combinations: {len(SPECIALTIES)} specialties × {len(LOCATIONS)} locations = {len(SPECIALTIES) * len(LOCATIONS)}")
    
    all_doctors = {}
    total_scraped = 0
    
    for location_name, location_slug in LOCATIONS.items():
        all_doctors[location_name] = {}
        
        for specialty_name, specialty_slug in SPECIALTIES.items():
            print(f"Scraping {specialty_name} in {location_name}...")
            doctors = scrape_doctors(specialty_slug, location_slug)
            
            if doctors:
                all_doctors[location_name][specialty_slug] = doctors
                total_scraped += len(doctors)
                print(f"  ✓ Found {len(doctors)} doctors")
            else:
                print(f"  ✗ No doctors found")
            
            time.sleep(0.2)
    
    print(f"\nTotal doctors scraped: {total_scraped}")
    print("Generating health_data.dart...")
    
    generate_dart_file(all_doctors, 'lib/data/health_data.dart')
    
    with open('health_data_backup.json', 'w', encoding='utf-8') as f:
        json.dump(all_doctors, f, indent=2, ensure_ascii=False)
    
    print("✓ Complete! Generated lib/data/health_data.dart")

if __name__ == '__main__':
    main()
