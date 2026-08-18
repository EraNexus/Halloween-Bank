drop table if exists branch;
drop table if exists loan;
drop table if exists account;
drop table if exists customer;
drop table if exists borrower;
drop table if exists depositor;
drop table if exists checkingAccount;
drop table if exists savingsAccount;

drop trigger if exists prevent_negative_savings_balance;
drop trigger if exists set_overdraft_flag;
drop trigger if exists add_depositor_on_account;
drop trigger if exists delete_depositor_on_account_removal;

drop procedure if exists processDeposit;

create table branch (
	branchName varchar(100) primary key,
    assets varchar(500),
    location varchar(200)
	);
    
create table loan (
	loanNumber int primary key,
    amount int,
    branchName varchar(100),
    foreign key (branchName) references branch(branchName)
    );
    
create table account (
	accountNumber int primary key,
    balance int,
    accountType varchar(100)
    );
    
create table customer (
	ssn varchar(11) primary key,
    customerName varchar(100)
    );
    
create table borrower (
	ssn varchar(11) primary key,
    customerName varchar(100),
    loanNumber int,
    foreign key (ssn) references customer(ssn),
    foreign key (loanNumber) references loan(loanNumber)
    );
    
create table depositor (
	ssn varchar(11) primary key,
    customerName varchar(100),
    accountNumber int,
    foreign key (ssn) references customer(ssn),
    foreign key (accountNumber) references account(accountNumber)
    );
    
create table checkingAccount (
	accountNumber int primary key,
    balance int,
    overdraft tinyint,
    foreign key (accountNumber) references account(accountNumber)
    );
    
create table savingsAccount (
	accountNumber int primary key,
    balance int,
    interestRate int,
    foreign key (accountNumber) references account(accountNumber)
    );

delimiter %%
create trigger prevent_negative_savings_balance
	before update on savingsAccount
    for each row
    begin
		if new.balance < 0 then
			signal sqlstate '45000'
            set message_text = 'Error: Savings account balance cannot be negative.';
		end if;
	end %%
    
create trigger set_overdraft_flag
	before update on checkingAccount
    for each row
    begin
		if new.balance < 0 then
			set new.overdraft = 1;
		else
			set new.overdraft = 0;
		end if;
	end %%
    
create trigger add_depositor_on_account
	after insert on account
    for each row
    begin
		insert into depositor (ssn, customerName, accountNumber)
        select ssn, customerName, new.accountNumber
        from customer
        where ssn not in (select ssn from depositor);
	end %%
    
create trigger delete_depositor_on_account_removal
	after delete on account
    for each row
    begin
		delete from depositor where accountNumber = old.accountNumber;
	end %%
    

create procedure processDeposit (
	in p_accountNumber int,
    in p_amount decimal(10,2)
)
begin
	declare exit handler for sqlexception
    begin
		rollback;
        signal sqlstate '45000'
			set message_text = 'Deposit failed: transaction rolled back.';
	end;
    if p_amount <= 0 then
		signal sqlstate '45000'
			set message_text = 'Invalid deposit amount.';
	end if;
	start transaction;
    if not exists (select 1 from account where accountNumber = p_accountNumber)
		then signal sqlstate '45000'
			set message_text = 'Account does not exist.';
	end if;
    update account
    set balance = balance + p_amount
    where accountNumber = p_accountNumber;
    commit;
end%%

delimiter ;

# Sample test

insert into branch values ('NorthSpook', '500000', 'Transylvania Avenue');
insert into customer values ('111-22-3333', 'Evan');
insert into account values (20001, 100, 'Checking');
insert into checkingAccount values (20001, 100, 00);

select * from depositor;

call processDeposit(20001, 150.00);

select * from account where accountNumber = 20001;