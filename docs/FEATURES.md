# Feature decisions

This is the maintained home for product behavior and design decisions. Add new decisions here as features are built; keep generated Spec Kit artifacts in `specs/` focused on implementation workflow.

## Financial plans

### Planned expense source account

When editing a pending expense on a financial plan, users can change its source account. Opening the picker shows all active accounts in the household, including asset accounts and liabilities such as credit cards. The current account name is selected in the search field, so typing replaces it and filters the options; users choose a valid account from the results. Account ownership remains validated by the planned expense model.

This reflects that a planned expense may be paid from cash or debit, or charged to a credit card. The source account is the actual account that will fund or record the expense, not necessarily an asset account.
