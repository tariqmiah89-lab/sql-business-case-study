"""Generates a synthetic e-commerce dataset (seeded, reproducible) and loads it into SQLite."""
import numpy as np, pandas as pd, sqlite3, os
rng = np.random.default_rng(42)

regions = ["London","South East","North West","Midlands","Scotland","Wales"]
reg_p = [.30,.18,.15,.17,.12,.08]
cats = {"Electronics":(25,400),"Home & Kitchen":(8,120),"Fitness":(10,150),"Books":(5,30),"Fashion":(15,140),"Beauty":(6,60)}

# products
prod = []
pid = 1
for c,(lo,hi) in cats.items():
    for i in range(7):
        prod.append((pid, f"{c.split()[0]} Item {i+1:02d}", c, round(float(rng.uniform(lo,hi)),2)))
        pid += 1
products = pd.DataFrame(prod, columns=["product_id","product_name","category","unit_price"])

# customers
n_c = 2500
signup = pd.to_datetime("2024-01-01") + pd.to_timedelta(rng.integers(0, 600, n_c), unit="D")
customers = pd.DataFrame({
    "customer_id": np.arange(1, n_c+1),
    "region": rng.choice(regions, n_c, p=reg_p),
    "signup_date": signup.strftime("%Y-%m-%d"),
    "channel": rng.choice(["Organic","Paid Search","Social","Email","Referral"], n_c, p=[.3,.25,.2,.15,.1]),
})

# orders: customers order a Poisson number of times after signup, with seasonality
end = pd.to_datetime("2025-12-31")
orders, items = [], []
oid = 1
season = {1:.8,2:.75,3:.9,4:.95,5:1.0,6:1.0,7:.95,8:.9,9:1.0,10:1.1,11:1.5,12:1.6}
for _, c in customers.iterrows():
    sd = pd.to_datetime(c.signup_date)
    span = (end - sd).days
    n = rng.poisson(max(span/110, 0.5))
    if n == 0: n = 1 if rng.random() < .7 else 0
    days = np.sort(rng.integers(0, max(span,1), n))
    for d in days:
        dt = sd + pd.Timedelta(days=int(d))
        if rng.random() > season[dt.month]/1.6 + .25: 
            continue
        disc = float(rng.choice([0,0,0,.05,.1,.2], p=[.4,.2,.1,.1,.12,.08]))
        orders.append((oid, int(c.customer_id), dt.strftime("%Y-%m-%d"), disc, rng.choice(["Card","PayPal","Apple Pay"], p=[.6,.25,.15])))
        for p in rng.choice(products.product_id, rng.integers(1,5), replace=False):
            items.append((oid, int(p), int(rng.integers(1,4))))
        oid += 1
orders = pd.DataFrame(orders, columns=["order_id","customer_id","order_date","discount_rate","payment_method"])
items = pd.DataFrame(items, columns=["order_id","product_id","quantity"])

os.makedirs("data", exist_ok=True)
for name, df in [("customers",customers),("products",products),("orders",orders),("order_items",items)]:
    df.to_csv(f"data/{name}.csv", index=False)
con = sqlite3.connect("data/shop.db")
con.executescript(open("sql/schema.sql").read())
for name, df in [("customers",customers),("products",products),("orders",orders),("order_items",items)]:
    df.to_sql(name, con, if_exists="append", index=False)
con.commit(); con.close()
print({k:len(v) for k,v in dict(customers=customers,products=products,orders=orders,order_items=items).items()})
