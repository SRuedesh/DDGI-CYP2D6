**Figure 1-1** shows the developed CYP2D6 DDGI network of interacting perpetrator and victim drugs. (a) Schematic illustration of the modeled interactions of CYP2D6 perpetrator and victim drugs. Black arrows indicate metabolism or transport, green arrows indicate induction, red solid lines indicate competitive inhibition, and red dashed lines indicate down-regulation (bupropion), noncompetitive inhibition (verapamil P-gp inhibition), or mechanism-based inactivation (other compounds). (b-c) Drug-drug-(gene) interaction matrices for modeled interactions mediated by (b) CYP2D6 and (c) CYP3A4 and P-gp. Colors indicate categories according to the [U.S. Food and Drug Administration](#references) examples of drugs that interact with CYP enzymes and transporter systems. The height of the grey ribbons indicates the number of clinical studies for the respective interaction covered by the network. Numbers in brackets indicate the number of clinical interaction studies for the corresponding compound. CYP: cytochrome P450, P-gp: P-glycoprotein.


![CYP2D6 DDGI modeling network](images/Figure_1_DDGI_Network.png)

**Figure 1-1: CYP2D6 DDGI modeling network**


The following victim and/or perpetrator PBPK models were applied: 

- **Alprazolam**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Alprazolam-Model/blob/master/Alprazolam-Model.json
- **Atomoxetine**
  Model snapshot: https://github.com/SRuedesh/Atomoxetine-Model/blob/bd042057586321df679d53ac1ef006dfcfeaa88a/Atomoxetine-model.json
- **Bupropion**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Bupropion-Model/blob/main/Bupropion-Model.json 
- **Carbamazepine**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Carbamazepine-Model/blob/main/Carbamazepine-Model.json
- **Cimetidine**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Cimetidine-Model/blob/master/Cimetidine-Model.json
- **Clarithromycin**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Clarithromycin-Model/blob/master/Clarithromycin-Model.json
- **(E)-Clomiphene** 
  Model snapshot: https://github.com/SRuedesh/Clomiphene-Model/blob/86cc674554c1b2fa6470e35c1afe19a0d01938bb/Clomiphene-Model.json
- **Desipramine** 
  Model snapshot: https://github.com/SRuedesh/Desipramine-Model/blob/5c3286b6d4f1aeb764488710e18aa5beeaabd4d8/Desipramine-Model.json
- **Dextromethorphan** 
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Dextromethorphan-Model/blob/main/dextromethorphan_aggregated_simulations.json
- **Digoxin** 
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Digoxin-Model/blob/master/Digoxin.json
- **Erythromycin** 
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Erythromycin-Model/blob/master/Erythromycin-Model.json
- **Fluvoxamine**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Fluvoxamine-Model/blob/master/Fluvoxamine-Model.json
- **Itraconazole**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Itraconazole-Model/blob/master/Itraconazole-Model.json
- **Ketoconazole**
  Model snapshot: https://github.com/SRuedesh/Ketoconazole-Model/blob/91d24c1075a17d122039fe37dadc893d9e1af987/Ketoconazole-Model.json
- **Metoprolol**
  Model snapshot: https://github.com/SRuedesh/Metoprolol-Model/blob/c16fb746829e4e38707947bedbfe489048c2bc38/Metoprolol-Model.json
- **Mexiletine** 
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Mexiletine-Model/blob/main/Mexiletine-Model.json
- **Omeprazole**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Omeprazole-Model/blob/main/Omeprazole-Model.json
- **Paroxetine** 
  Model snapshot: https://github.com/SRuedesh/Paroxetine-Model/blob/42e7f0eeb22588afbff74fdf1b5c27f744aabb0c/Paroxetine-Model.json
- **Quinidine** 
  Model snapshot: https://github.com/SRuedesh/Quinidine-Model/blob/10e7e31a07e906b9cde38fedf37d75fd6992fb1c/Quinidine-Model.json
- **Rifampicin**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Rifampicin-Model/blob/master/Rifampicin-Model.json
- **Risperidone**
  Model snapshot: https://github.com/SRuedesh/Risperidone-Model/blob/b2c802af803ee0fcf76af56f19dd9ff6df7ddae9/Risperidone-model.json
- **Verapamil**
  Model snapshot: https://github.com/Open-Systems-Pharmacology/Verapamil-Model/blob/master/Verapamil-Model.json


The following interaction scenarios were predicted and used to qualify the final DDGI network:

- Alprazolam as victim:
  - Paroxetine-alprazolam-DDI

- Atomoxetine as victim:
  - Bupropion-atomoxetine-DDGI
  - Fluvoxamine-atomoxetine-DDI
  - Paroxetine-atomoxetine-DDGI

- (E)-Clomiphene as victim:
  - Clarithromycin-clomiphene-DDGI
  - Paroxetine-clomiphene-DDGI

- Desipramine as victim:
  - Atomoxetine-desipramine-DDI
  - Bupropion-desipramine-DDI
  - Paroxetine-desipramine-DDGI
  - Quinidine-desipramine-DDI

- Dextromethorphan as victim:
  - Paroxetine-dextromethorphan-DDGI
  - Quinidine-dextromethorphan-DDI

- Digoxin as victim: 
  - Quinidine-digoxin-DDI

- Metoprolol as victim:
  - Cimetidine-metoprolol-DDI
  - Paroxetine-metoprolol-DDI
  - Quinidine-metoprolol-DDGI
  - Rifampicin-metoprolol-DDI

- Mexiletine as victim: 
  - Quinidine-mexiletine-DDGI

- Midazolam as victim: 
  - Atomoxetine-midazolam-DDI

- Paroxetine as victim:
  - Itraconazole-paroxetine-DDI
  - Quinidine-paroxetine-DDI

- Quinidine as victim: 
  - Carbamazepine-quinidine-DDI
  - Cimetidine-quinidine-DDI
  - Erythromycin-quinidine-DDI
  - Fluvoxamine-quinidine-DDI
  - Itraconazole-quinidine-DDI
  - Omeprazole-quinidine-DDI
  - Rifampicin-quinidine-DDI
  - Verapamil-quinidine-DDI

- Risperidone as victim:
  - Ketoconazole-risperidone-DDI
  - Rifampicin-risperidone-DDI
  - Verapamil-risperidone-DDI


The published DD(G)I studies between the respective perpetrators and victim drugs were simulated and compared to observed data. The following sections give an overview of the clinical studies being part of this qualification report.
