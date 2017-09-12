"# Galactikka ICO Contracts README" 

Token.sol - Token contract

Ico.sol - Ico round contract

Distributor.sol - Contract to distribute collected money by specified sharing scheme

1) Deploy Token and Distributor contracts, configure them, lock

2) Deploy ICO contacts, all of them 

3) Configure ICO contracts, at this step you'll need to know Token, Distributor and ICO contract addresses generated in steps 1-2

4) Lock ICO contracts

5) Watch the ICO

6) Call checkResults on each round completion to withdraw money to distributor (if mincap reached)

7) Each desintation wallet registered in distributor will have to call withdraw to get its balance from distributor
