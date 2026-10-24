HiDiveDb

2401322041 Виктор Иванов

University project for the Software Modeling & Analysis course. This repository contains the database design, SQL Server implementation, and Power BI analytics for a custom anime streaming platform.

What's Inside
/Diagrams: Conceptual (Chen notation), Logical (Crow's Foot), and the physical Data Warehouse (UML) models.

/SQL: The HiDiveDb_Setup.sql master script. This builds the OLTP database across 3 schemas (Accounts, Content, Engagement), sets up functions/procedures/triggers, and seeds the mock data.

/BI: The Power BI report (.pbix) built on top of the Fact Constellation data warehouse schema.

Setup
Open SQL Server Management Studio (SSMS).

Run the HiDiveDb_Setup.sql script to create and populate the database.

Open the .pbix file in Power BI to view the visualizations.