# Mathematical Performance Model for DT-HSBP

This document establishes the complete analytical framework for the **Digital Twin–Assisted Hierarchical Secure Broadcast Protocol (DT-HSBP)** in accordance with the supervisor's research checklist, linking the stochastic event processes to closed-form equations for communication cost, computational overhead, efficiency, and scalability.

---

## 1. Stochastic Event Modeling (Checklist Points 2, 3, 4)

### 1.1 Model Selection & Justification (Poisson Point Process)
In dynamic Unmanned Aerial Vehicle (UAV) swarms, membership events (node arrival/join, voluntary departure/leave, and component or link failure) are driven by independent operational and environmental factors across distributed nodes. The standard and mathematically rigorous model for such memoryless, independent dynamic event arrivals is a **homogeneous Poisson Point Process (PPP)**:
- **Stationary increments:** Event rates remain invariant over operational intervals.
- **Independent increments:** The occurrence of an event in one time interval $[t_1, t_2]$ is independent of occurrences in disjoint intervals.
- **Single events:** The probability of simultaneous overlapping arrivals in an infinitesimal window $dt$ is $o(dt)$.

### 1.2 Event Rates and Probability Distributions
Let $T$ be the simulation or operational time window. We define three independent Poisson arrival streams:
1. **Join rate:** $\lambda_J > 0$ (events/second)
2. **Leave rate:** $\lambda_L > 0$ (events/second)
3. **Failure rate:** $\lambda_F > 0$ (events/second)

For an observation window $\Delta t$, the number of events $N_X(\Delta t)$ of type $X \in \{J, L, F\}$ follows:
$$P(N_X(\Delta t) = k) = \frac{(\lambda_X \Delta t)^k e^{-\lambda_X \Delta t}}{k!}, \quad k \in \{0, 1, 2, \dots\}$$

The combined exogenous event stream $N(t) = N_J(t) + N_L(t) + N_F(t)$ is a merged Poisson process with aggregated rate:
$$\lambda = \lambda_J + \lambda_L + \lambda_F$$

The probability of an event occurrence within time $\Delta t$ is:
$$P(\text{Event in } \Delta t) = 1 - e^{-\lambda \Delta t}$$

The probability of each distinct event type conditioned on an event occurring is:
$$P(\text{Join} \mid \text{Event}) = \frac{\lambda_J}{\lambda}, \quad P(\text{Leave} \mid \text{Event}) = \frac{\lambda_L}{\lambda}, \quad P(\text{Failure} \mid \text{Event}) = \frac{\lambda_F}{\lambda}$$

> [!IMPORTANT]
> **Clarification of Event Probabilities vs. Stability Probability:**
> - $P(N_X = k)$ models the **arrival probability of exogenous network events** (membership churn).
> - This is strictly separate from the **probability of UAV physical stability**, which is modeled by the Digital Twin state residual $D_i(t) = \|\mathbf{e}_i(t)\|_2$.

### 1.3 Statistical Moments (Checklist Point 5)
For each event type $X \in \{J, L, F\}$ over horizon $T$:
- **Mean (Expected Value):**
  $$\mu_X = \mathbb{E}[N_X(T)] = \lambda_X T$$
- **Variance:**
  $$\sigma_X^2 = \text{Var}(N_X(T)) = \lambda_X T$$
- **Standard Deviation:**
  $$\sigma_X = \text{SD}(N_X(T)) = \sqrt{\lambda_X T}$$

For empirical realizations across $R$ independent repetitions ($r = 1, \dots, R$):
$$\bar{X} = \frac{1}{R} \sum_{r=1}^R X_r, \quad s^2 = \frac{1}{R-1} \sum_{r=1}^R (X_r - \bar{X})^2, \quad s = \sqrt{s^2}$$

---

## 2. Mathematical Performance Model (Checklist Points 6, 7, 8, 9, 10, 11)

### 2.1 Swarm Architecture & Parameters
- Total swarm size: $N$ UAVs
- Number of clusters: $K$ clusters
- Average cluster size: $n_c = \frac{N}{K}$
- Symmetric cryptographic key size: $b_k$ bytes (e.g., 32 bytes for AES-256)
- Message overhead (headers + control metadata): $b_{\text{hdr}}$ bytes
- Total packet size per rekey message: $b = b_{\text{hdr}} + b_k = 56$ bytes

### 2.2 Mathematical Communication Cost Model ($C_{\text{comm}}$)

#### A. Flat-SBP Baseline
In Flat-SBP, every join, leave, or failure triggers a swarm-wide broadcast from the Swarm Leader (SL) to all $N$ UAVs:
- **Join event:** $N+1$ UAVs receive the new key:
  $$M_{\text{Flat}}^J(N) = N + 1$$
- **Leave / Failure event (for $B$ departing UAVs):**
  If departures occur reactively, each requires a swarm broadcast:
  $$M_{\text{Flat}}^L(N) = \sum_{j=1}^B (N - j) \approx B \cdot N$$
- **Communication Cost in Bytes:**
  $$C_{\text{comm}}^{\text{Flat}}(N) = b \cdot M_{\text{Flat}}(N)$$

#### B. HSBP Baseline (Hierarchical Reactive without DT)
In HSBP, rekeying is localized within the affected cluster $C_j$:
- **Join event:** Only the affected cluster updates:
  $$M_{\text{HSBP}}^J(N) = n_c + 1 = \frac{N}{K} + 1$$
- **Leave / Failure event (for $B$ departures without predictive batching):**
  Each departure triggers an independent local rekey:
  $$M_{\text{HSBP}}^L(N) = \sum_{j=1}^B \left(\frac{N}{K} - j\right) \approx B \cdot \frac{N}{K}$$
- **Communication Cost in Bytes:**
  $$C_{\text{comm}}^{\text{HSBP}}(N) = b \cdot M_{\text{HSBP}}(N)$$

#### C. DT-HSBP Proposed Protocol (Predictive & Proactive Batch Rekeying)
In DT-HSBP, the embedded Digital Twin monitors UAV kinematics, residual energy, and link quality:
1. **Instability Detection:** When a UAV $u_i$ experiences physical disturbances or packet loss, its DT residual exceeds the departure threshold $D_i(t) > \theta_{\text{leave}}$.
2. **Hazard-Driven Realization:** The probability that an unstable UAV materializes as a departure within horizon $H$ is governed by the threshold-anchored hazard:
   $$\lambda_{\text{DT}}(S) = \lambda_L \exp\left(\frac{S}{\theta_{\text{leave}}} - 1\right), \quad P_{\text{realize}}(S, H) = 1 - \exp\left(-\lambda_{\text{DT}}(S) H\right)$$
3. **Cluster-Local Batch Rekeying:** When a rekey is triggered in cluster $C_j$, all $B$ departing/unstable UAVs in that cluster are excluded **simultaneously in a single rekey round**:
   - **Join event:** Same as HSBP, with predictive admission filtering:
     $$M_{\text{DT}}^J(N) = \frac{N}{K} + 1$$
   - **Leave / Batch Leave event:** All $B$ realized departures are batched into **1 single cluster broadcast**:
     $$M_{\text{DT}}^L(N) = \frac{N}{K} - B$$
   - **Rekey rounds:** $R_{\text{DT}} = 1$ (compared to $R_{\text{HSBP}} = B$).

$$\boxed{C_{\text{comm}}^{\text{DT}}(N) = b \cdot \left(\frac{N}{K} - B\right)}$$

---

### 2.3 Mathematical Computational Cost Model ($C_{\text{comp}}$)

Let:
- $T_{\text{DH}}(m)$: computation time to evaluate a sequential Diffie–Hellman chain of length $m$.
- $T_{\text{enc}}$: symmetric key encryption/generation cost.
- $T_{\text{dec}}$: follower symmetric key decryption cost.

#### A. Leader Computation Time ($C_{\text{leader}}$)
- **Flat-SBP:** Leader must recompute the sequential key across the entire swarm:
  $$C_{\text{leader}}^{\text{Flat}} = \mathcal{O}(N) = N \cdot T_{\text{DH}}$$
- **HSBP:** Only the Cluster Head (CH) recomputes the chain, but must do so for each of the $B$ sequential departures:
  $$C_{\text{leader}}^{\text{HSBP}} = B \cdot \mathcal{O}(n_c) = B \cdot \frac{N}{K} \cdot T_{\text{DH}}$$
- **DT-HSBP:** The CH recomputes the chain **once** for the remaining $(n_c - B)$ stable members:
  $$C_{\text{leader}}^{\text{DT}} = \mathcal{O}(n_c - B) = \left(\frac{N}{K} - B\right) \cdot T_{\text{DH}}$$

#### B. Follower Computation Time ($C_{\text{follower}}$)
- **Flat-SBP:** All $N$ followers decrypt and update the key for each departure:
  $$C_{\text{follower}}^{\text{Flat}} = B \cdot N \cdot T_{\text{dec}}$$
- **HSBP:** Followers in the affected cluster update $B$ times:
  $$C_{\text{follower}}^{\text{HSBP}} = B \cdot \frac{N}{K} \cdot T_{\text{dec}}$$
- **DT-HSBP:** Followers in the affected cluster update **once**:
  $$C_{\text{follower}}^{\text{DT}} = \left(\frac{N}{K} - B\right) \cdot T_{\text{dec}}$$

---

### 2.4 Communication Efficiency & Performance Gain (Checklist Points 9, 10)

We define the Communication Efficiency $\eta$ as the ratio of useful key dissemination payload to total transmitted bytes:
$$\eta = \frac{b_k}{b} \cdot \frac{1}{\text{Rekeys}}$$

The Performance Gain $G(N)$ of DT-HSBP relative to a baseline protocol $\mathcal{B} \in \{\text{Flat-SBP}, \text{HSBP}\}$ is defined as:
$$G_{\text{comm}}^{\mathcal{B}}(N) = \frac{C_{\text{comm}}^{\mathcal{B}}(N) - C_{\text{comm}}^{\text{DT}}(N)}{C_{\text{comm}}^{\mathcal{B}}(N)} \times 100\%$$

#### Gain against Flat-SBP:
$$G_{\text{comm}}^{\text{Flat}}(N) = \frac{B \cdot N - \left(\frac{N}{K} - B\right)}{B \cdot N} \times 100\% = \left(1 - \frac{1}{B K} + \frac{1}{N}\right) \times 100\%$$
For $K = 5$ clusters and $B = 3$ batch departures:
$$G_{\text{comm}}^{\text{Flat}}(N) \approx \left(1 - \frac{1}{15}\right) \times 100\% = \mathbf{93.33\%}$$

#### Gain against HSBP:
$$G_{\text{comm}}^{\text{HSBP}}(N) = \frac{B \cdot \frac{N}{K} - \left(\frac{N}{K} - B\right)}{B \cdot \frac{N}{K}} \times 100\% = \left(1 - \frac{1}{B} + \frac{K}{N}\right) \times 100\%$$
For $B = 3$ departures in a cluster:
$$G_{\text{comm}}^{\text{HSBP}}(N) \approx \left(1 - \frac{1}{3}\right) \times 100\% = \mathbf{66.67\%}$$

---

## 3. Mathematical Justification of DT Overhead Reduction (Checklist Point 13)

Why does the Digital Twin mathematically reduce rekeying overhead?

1. **Elimination of Desynchronization Recovery Penalty:**
   In reactive protocols (Flat-SBP, HSBP), an unstable UAV (experiencing link degradation or imminent power failure) is included in the rekey broadcast. When it fails to receive the rekey message, the Diffie-Hellman chain or group key breaks, triggering a costly **recovery rekey protocol** with communication penalty $C_{\text{recovery}} = \mathcal{O}(N)$ and latency timeout $T_{\text{timeout}}$.
   Under DT-HSBP:
   $$P_{\text{desync}}^{\text{DT}} = P\left(D_i(t) \le \theta_{\text{leave}} \;\middle|\; \text{UAV fails in } H\right) \to 0$$
   Unstable UAVs are proactively excluded **before** cryptographic synchronization, eliminating recovery cycles.

2. **Batch Amortization Factor:**
   When $B$ unstable nodes are detected within the DT prediction window $H$, DT-HSBP amortizes the rekeying cost across all $B$ departures into a single cryptographic transition. The rekey reduction factor is exactly:
   $$\mathcal{R}_{\text{factor}} = \frac{R_{\text{DT}}}{R_{\text{HSBP}}} = \frac{1}{B}$$
   This reduces the number of rekeys by $\left(1 - \frac{1}{B}\right) \times 100\%$.

---

## 4. Scalability Analysis (Checklist Point 14)

As the swarm size $N \to \infty$ with a fixed number of clusters $K$, or when $K = \mathcal{O}(\sqrt{N})$:

| Metric | Flat-SBP | HSBP | DT-HSBP | DT-HSBP Scalability Impact |
| :--- | :--- | :--- | :--- | :--- |
| **Leader Comp. Time** | $\mathcal{O}(N)$ | $\mathcal{O}(N/K)$ | $\mathcal{O}(N/K)$ | **Near-constant per cluster** |
| **Follower Comp. Time** | $\mathcal{O}(N)$ | $\mathcal{O}(N/K)$ | $\mathcal{O}(N/K)$ | **Independent of non-affected clusters** |
| **Message Overhead (Join)** | $N+1$ | $N/K + 1$ | $N/K + 1$ | **Localized by factor of $1/K$** |
| **Message Overhead (Leave)** | $B \cdot N$ | $B \cdot (N/K)$ | $\frac{N}{K} - B$ | **Amortized by factor of $\frac{1}{B K}$** |
| **SL Communication Overhead** | $\mathcal{O}(N)$ | $\mathcal{O}(K)$ | $\mathcal{O}(K)$ | **Strictly $\mathcal{O}(K)$, invariant to $N$** |

---

## 5. Multi-Scale Experimental Results & Model Validation (Checklist Points 5, 12)

The Stage E Full Join/Leave Study was executed across the five established swarm sizes $N \in [1000, 2000, 3000, 4000, 5000]$ with 3 repetitions per configuration (90 total runs) under paired Poisson event workloads.

### 5.1 Join Event Numerical Performance (Single Drone Join)

| Swarm Size ($N$) | Protocol | EvtMean ($\bar{N}_J$) | Leader Time (ms) | Follower Time (ms) | Messages Sent ($\bar{M}$) | Bytes Transmitted ($\bar{C}_{\text{comm}}$) | Rekeys |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1000** | Flat-SBP | 59.0 | $5.83 \pm 0.27$ | $0.062 \pm 0.047$ | $1001.0 \pm 0.0$ | $56,056 \pm 0$ | $1.0 \pm 0.0$ |
| | HSBP | 59.0 | $1.17 \pm 0.02$ | $0.024 \pm 0.028$ | $201.0 \pm 0.0$ | $11,256 \pm 0$ | $1.0 \pm 0.0$ |
| | **DT-HSBP** | 59.0 | **$1.19 \pm 0.04$** | **$0.026 \pm 0.028$** | **$201.0 \pm 0.0$** | **$11,256 \pm 0$** | **$1.0 \pm 0.0$** |
| **2000** | Flat-SBP | 59.0 | $11.75 \pm 0.13$ | $0.085 \pm 0.004$ | $2001.0 \pm 0.0$ | $112,056 \pm 0$ | $1.0 \pm 0.0$ |
| | HSBP | 59.0 | $2.35 \pm 0.10$ | $0.015 \pm 0.002$ | $401.0 \pm 0.0$ | $22,456 \pm 0$ | $1.0 \pm 0.0$ |
| | **DT-HSBP** | 59.0 | **$2.38 \pm 0.12$** | **$0.016 \pm 0.002$** | **$401.0 \pm 0.0$** | **$22,456 \pm 0$** | **$1.0 \pm 0.0$** |
| **3000** | Flat-SBP | 59.0 | $17.72 \pm 0.66$ | $0.133 \pm 0.012$ | $3001.0 \pm 0.0$ | $168,056 \pm 0$ | $1.0 \pm 0.0$ |
| | HSBP | 59.0 | $3.50 \pm 0.04$ | $0.023 \pm 0.003$ | $601.0 \pm 0.0$ | $33,656 \pm 0$ | $1.0 \pm 0.0$ |
| | **DT-HSBP** | 59.0 | **$3.47 \pm 0.09$** | **$0.022 \pm 0.002$** | **$601.0 \pm 0.0$** | **$33,656 \pm 0$** | **$1.0 \pm 0.0$** |
| **4000** | Flat-SBP | 59.0 | $22.36 \pm 0.38$ | $0.153 \pm 0.016$ | $4001.0 \pm 0.0$ | $224,056 \pm 0$ | $1.0 \pm 0.0$ |
| | HSBP | 59.0 | $4.44 \pm 0.03$ | $0.024 \pm 0.001$ | $801.0 \pm 0.0$ | $44,856 \pm 0$ | $1.0 \pm 0.0$ |
| | **DT-HSBP** | 59.0 | **$4.40 \pm 0.05$** | **$0.023 \pm 0.001$** | **$801.0 \pm 0.0$** | **$44,856 \pm 0$** | **$1.0 \pm 0.0$** |
| **5000** | Flat-SBP | 59.0 | $27.88 \pm 0.08$ | $0.201 \pm 0.005$ | $5001.0 \pm 0.0$ | $280,056 \pm 0$ | $1.0 \pm 0.0$ |
| | HSBP | 59.0 | $5.62 \pm 0.08$ | $0.031 \pm 0.002$ | $1001.0 \pm 0.0$ | $56,056 \pm 0$ | $1.0 \pm 0.0$ |
| | **DT-HSBP** | 59.0 | **$5.57 \pm 0.07$** | **$0.031 \pm 0.001$** | **$1001.0 \pm 0.0$** | **$56,056 \pm 0$** | **$1.0 \pm 0.0$** |

### 5.2 Leave Event Numerical Performance (Batch & Predictive Leave)

| Swarm Size ($N$) | Protocol | EvtMean ($\bar{N}_L$) | Leader Time (ms) | Follower Time (ms) | Messages Sent ($\bar{M}$) | Message Overhead (KB) | Rekeys per Ep. | DT-HSBP Comm Gain |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1000** | Flat-SBP | 37.0 | $64.12 \pm 2.05$ | $27.48 \pm 0.88$ | $2903.9 \pm 6.7$ | $158.81 \pm 0.37$ | $2.9 \pm 0.0$ | **$93.21\%$ vs Flat** |
| | HSBP | 37.0 | $18.39 \pm 0.43$ | $7.88 \pm 0.18$ | $576.2 \pm 1.3$ | $31.51 \pm 0.07$ | $2.9 \pm 0.0$ | **$65.79\%$ vs HSBP** |
| | **DT-HSBP** | 37.0 | **$13.25 \pm 0.18$** | **$5.68 \pm 0.08$** | **$197.1 \pm 0.0$** | **$10.78 \pm 0.00$** | **$1.0 \pm 0.0$** | **(Baseline)** |
| **2000** | Flat-SBP | 37.0 | $126.32 \pm 1.97$ | $54.14 \pm 0.84$ | $5850.2 \pm 19.9$ | $319.93 \pm 1.09$ | $2.9 \pm 0.0$ | **$93.21\%$ vs Flat** |
| | HSBP | 37.0 | $36.96 \pm 0.84$ | $15.84 \pm 0.36$ | $1165.4 \pm 4.0$ | $63.73 \pm 0.22$ | $2.9 \pm 0.0$ | **$65.93\%$ vs HSBP** |
| | **DT-HSBP** | 37.0 | **$26.34 \pm 0.38$** | **$11.29 \pm 0.16$** | **$397.1 \pm 0.0$** | **$21.71 \pm 0.00$** | **$1.0 \pm 0.0$** | **(Baseline)** |
| **3000** | Flat-SBP | 37.0 | $191.15 \pm 13.23$ | $81.92 \pm 5.67$ | $8567.4 \pm 45.9$ | $468.53 \pm 2.51$ | $2.9 \pm 0.0$ | **$93.03\%$ vs Flat** |
| | HSBP | 37.0 | $57.30 \pm 5.83$ | $24.56 \pm 2.50$ | $1709.0 \pm 9.1$ | $93.46 \pm 0.50$ | $2.9 \pm 0.0$ | **$65.06\%$ vs HSBP** |
| | **DT-HSBP** | 37.0 | **$39.87 \pm 2.05$** | **$17.09 \pm 0.88$** | **$597.1 \pm 0.0$** | **$32.66 \pm 0.00$** | **$1.0 \pm 0.0$** | **(Baseline)** |
| **4000** | Flat-SBP | 37.0 | $253.55 \pm 1.99$ | $108.67 \pm 0.85$ | $11565.6 \pm 36.4$ | $632.50 \pm 1.99$ | $2.9 \pm 0.0$ | **$93.11\%$ vs Flat** |
| | HSBP | 37.0 | $76.01 \pm 1.74$ | $32.58 \pm 0.75$ | $2308.6 \pm 7.2$ | $126.25 \pm 0.40$ | $2.9 \pm 0.0$ | **$65.47\%$ vs HSBP** |
| | **DT-HSBP** | 37.0 | **$55.10 \pm 4.78$** | **$23.61 \pm 2.05$** | **$797.1 \pm 0.0$** | **$43.59 \pm 0.00$** | **$1.0 \pm 0.0$** | **(Baseline)** |
| **5000** | Flat-SBP | 37.0 | $365.49 \pm 47.87$ | $156.64 \pm 20.52$ | $14182.7 \pm 19.5$ | $775.62 \pm 1.07$ | $2.8 \pm 0.0$ | **$92.97\%$ vs Flat** |
| | HSBP | 37.0 | $101.97 \pm 4.81$ | $43.70 \pm 2.06$ | $2832.1 \pm 3.9$ | $154.88 \pm 0.21$ | $2.8 \pm 0.0$ | **$64.79\%$ vs HSBP** |
| | **DT-HSBP** | 37.0 | **$68.95 \pm 4.67$** | **$29.55 \pm 2.00$** | **$997.2 \pm 0.0$** | **$54.53 \pm 0.00$** | **$1.0 \pm 0.0$** | **(Baseline)** |

---

## 6. Publication Figures Generated

All figures have been rendered at 300 DPI and saved in [figures/](file:///h:/Master/Others/Zyad/07-2026/DT-HSBP/figures) and the artifacts directory:

````carousel
![Join Leader Execution Time](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Join_Leader_Execution_Time.png)
<!-- slide -->
![Join Follower Execution Time](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Join_Follower_Execution_Time.png)
<!-- slide -->
![Join Message Overhead](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Join_Message_Overhead.png)
<!-- slide -->
![Leave Leader Execution Time](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Leave_Leader_Execution_Time.png)
<!-- slide -->
![Leave Follower Execution Time](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Leave_Follower_Execution_Time.png)
<!-- slide -->
![Leave Message Overhead](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Leave_Message_Overhead.png)
<!-- slide -->
![Leave Rekey Activity](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Leave_Rekey_Activity.png)
<!-- slide -->
![Communication Performance Gain](C:/Users/Owner/.gemini/antigravity-ide/brain/08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f/Communication_Performance_Gain.png)
````

