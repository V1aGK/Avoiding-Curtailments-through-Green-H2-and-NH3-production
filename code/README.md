# Overview of the Optimization Model

This folder contains the GAMS model used in my thesis to evaluate the techno-economic performance of a green ammonia (NH3) production system under different future scenarios.

The model combines investment decisions, operational constraints, and scenario-based data to determine the optimal yearly performance of the system from 2026 to 2045. It also estimates the financial outputs, including revenue, energy costs, and net present value (NPV).

---

## 🎯 Purpose of the Model

The goal of the model is to simulate how a green ammonia production plant performs under uncertainty in:
- electricity availability,
- renewable energy curtailment,
- NH3 market prices,
- capital and operating costs,
- and technology efficiencies over time.

Using optimization, the model identifies how the system should operate each year to maximize economic performance while respecting technical constraints.

---

## 📥 Input Data

The model imports all scenario data directly from an Excel file (`Scenarios1.xlsx`) using **gdxxrw**.  
This includes:

- yearly time periods (2026–2045),
- electricity curtailment data (GWh),
- P25 power and energy curves,
- scenario variations (7 scenarios),
- NH₃ market prices for optimistic, base, and pessimistic forecasts,
- CAPEX and OPEX values for:
  - Electrolyzer (EL),
  - Haber–Bosch plant (HB),
  - Air Separation Unit (ASU).

All imported data is stored in GAMS parameters such as `YearData(y,scen,col)` for easy access.

---

## 🔧 System Components

### **Electrolyzer (EL)**
- Converts electricity to hydrogen.
- Has annual availability and energy-to-hydrogen efficiency.
- Includes CAPEX and OPEX cost structure.

### **Haber–Bosch (HB)**
- Converts hydrogen and nitrogen into ammonia.
- Has fixed and variable OPEX and yearly availability.
- Requires electricity input: `e_HB_MWh_per_tNH3`.

### **Air Separation Unit (ASU)**
- Produces nitrogen for NH₃ synthesis.
- Includes CAPEX, OPEX, availability, and electricity consumption.

---

## 📐 Decision Variables

The main decision variables include:
- EL annual hydrogen production,
- ASU nitrogen production,
- HB ammonia output,
- yearly maximum capacity utilization,
- investment-related capital costs,
- and revenue from ammonia sales.

The model computes whether the plant meets availability, energy, and mass balance constraints.

---

## 🧮 Objective Function

The objective is to **maximize the economic performance** of the ammonia system.  
This includes:

- annual revenue = NH₃ production × price,
- minus operating costs,
- minus amortized CAPEX effects,
- discounted over time to compute NPV.

Different market price scenarios (`Opt`, `Base`, `Pess`) allow the user to evaluate financial outcomes under uncertainty.

---

## 🧱 Constraints

The model includes constraints related to:

- **energy availability** (curtailed energy, P25 limits),
- **conversion efficiencies** (EL, HB, ASU),
- **annual capacity build-up**,  
- **technical limits** of each subsystem,
- **mass and energy balances** across the production chain,
- **availability factors** limiting operational hours.

These ensure that the modeled system behaves realistically.

---

## ▶️ How to Run the Model

Make sure the Excel file `Scenarios1.xlsx` is in the same directory.

Then run: gams model.gms

The model will:
1. Import data via gdxxrw  
2. Build all parameters and variables  
3. Solve the optimization problem  
4. Output results to the listing file (`.lst`) and GDX files, if enabled  

---

## 📊 Results

The model produces:
- annual ammonia production,
- electricity consumption,
- capacity utilization,
- yearly revenues and operating costs,
- scenario-dependent financial indicators.

Graphs and result exports are stored in the `results/` folder of the repository.


