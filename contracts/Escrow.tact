import "@stdlib/deploy";

message Withdraw{
    amount: Int as coins;
}

message WithdrawFeesNative {

}

message MakerFee{
    fee: Int;
}

message TakerFee{
    fee: Int;
}

message SetTime{
    seconds: Int;
}

message ReleaseEscrowOnlyOwner{
    orderId: Int;
}

message ReleaseEscrowOnlyMaker{
    orderId: Int;
}

message MarkPaid {
    orderId: Int;
}

message CancelMakerNative {
    orderId: Int;
}

message CancelTakerNative {
    orderId: Int;
}

message CreateEscrowNativeCoin{
    _orderId: Int;
    _taker: Address;
    _value: Int;
    _maker_premium: Bool;
    _taker_premium: Bool;
}

message RefundMakerNativeCoin {
    _orderId: Int;
}

struct EscrowData {
        maker: Address; //Maker
        taker: Address; //Taker
        maker_premium: Bool;
        taker_premium: Bool;
        value: Int as coins;// Purchase amount
        takerFee: Int as uint16; //Fee Taker
        makerFee: Int as uint16; //Fee Maker
        // currency; //Money will add later
        status: Int as uint8; //Status
        created: Int as uint256;
    }


contract Escrow with Deployable {
    const MinTonForStorage: Int = ton("0.01"); // 1 KB for 2.5 year to keep data into blockchain
    owner: Address;
    feeTaker: Int; 
    feeMaker: Int; 
    feesAvailableNativeCoin: Int as coins;
    timeProcess: Int;

    // OrderID against each set of escrow data
    escrows: map<Int, EscrowData>;

    // Status
    const Unknown: Int = 0;
    const ACTIVE: Int =  1;
    const CRYPTOS_IN_CUSTODY: Int =  2;
    const FIATCOIN_TRANSFERED: Int =  3;
    const COMPLETED: Int =  4;
    const REFUND: Int =  7;
    const CANCEL_MAKER: Int = 9;
    const CANCEL_TAKER: Int = 10;

    init() {
        self.owner = sender();
        self.feeMaker = 100;
        self.feeTaker = 100;
        self.feesAvailableNativeCoin = 0;
        self.timeProcess = 45*60; // 45 min
    }

    // ================== Begin External functions ==================

    receive(msg: MakerFee){
        self.onlyOwner();
        self.feeMaker = msg.fee;
    }


    receive(msg: TakerFee){
        self.onlyOwner();
        self.feeTaker = msg.fee;
    }

     receive(msg: SetTime){
        self.onlyOwner();
        self.timeProcess = msg.seconds;
    }

    receive(msg: CreateEscrowNativeCoin){
        let _taker: Address = msg._taker;
        let _value: Int = msg._value;
        let _orderId: Int = msg._orderId;
        let _maker_premium: Bool = msg._maker_premium;
        let _taker_premium: Bool = msg._taker_premium;

        if(self.escrows.get(_orderId) != null) {
        let escrow: EscrowData = self.escrows.get(_orderId)!!;
        require(
            escrow.status == self.Unknown,
            "Escrow already exists"
        );
        }
        
        // will check 0 add later
        // require(_taker != zero(0), "The address taker cannot be empty");

        require(sender() != _taker, "Taker cannot be the same as maker");

        require(_value > 0, "The parameter value cannot be zero");


        let _amountFeeMaker: Int = 0;

        if (!_maker_premium) {
            _amountFeeMaker = (_value * self.feeMaker) / 10000;

            //Add fee
            self.feesAvailableNativeCoin += _amountFeeMaker;    
        }

         //Verification was added for the user to send the exact amount of native tokens to escrow.
        require((_value + _amountFeeMaker) <= context().value, "Incorrect amount");

        // self.mi1.set(17, TokenInfo{ticker: "SHIB", decimals: 9});

        send(SendParameters{
            to: myAddress(),
            bounce: true,   
            value: context().value,
            mode: SendIgnoreErrors + SendRemainingValue
        });
        

        self.escrows.set(_orderId, EscrowData{
            maker: sender(),
            taker: _taker,
            maker_premium: _maker_premium,
            taker_premium: _taker_premium,
            value: _value,
            takerFee: self.feeTaker,
            makerFee: self.feeMaker,
            // IERC20(address(0)),
            status: self.CRYPTOS_IN_CUSTODY,
            created: now()
    });

    dump(self.feesAvailableNativeCoin);

    }

    receive (msg: MarkPaid) {
        // self.onlyTaker();
        let escrow: EscrowData = self.escrows.get(msg.orderId)!!;

         require(
            escrow.status == self.CRYPTOS_IN_CUSTODY,
            "Status must be CRYPTOS_IN_CUSTODY"
        );

      self.escrows.set(msg.orderId, EscrowData{
            maker: sender(),
            taker: escrow.taker,
            maker_premium: escrow.maker_premium,
            taker_premium: escrow.taker_premium,
            value: escrow.value,
            takerFee: self.feeTaker,
            makerFee: self.feeMaker,
            // IERC20(address(0)),
            status: self.FIATCOIN_TRANSFERED,
            created: now()
        });
    }

    receive (msg: ReleaseEscrowOnlyOwner) {
        // self.onlyMaker();
        let escrow: EscrowData = self.escrows.get(msg.orderId)!!;

        require(
            escrow.status == self.FIATCOIN_TRANSFERED,
            "Native Coin has not been deposited"
        );

        //Gets the amount to transfer from the buyer to the contract
        let _amountFeeTaker: Int = 0;
        if (!escrow.taker_premium) {
            _amountFeeTaker = self.getAmountFeeTaker(msg.orderId);    
        }

        //Record the fees obtained for Paydece

        self.feesAvailableNativeCoin += _amountFeeTaker;

        // write as complete, in case transfer fails
        self.escrows.set(msg.orderId, EscrowData{
            maker: sender(),
            taker: escrow.taker,
            maker_premium: escrow.maker_premium,
            taker_premium: escrow.taker_premium,
            value: escrow.value,
            takerFee: self.feeTaker,
            makerFee: self.feeMaker,
            // IERC20(address(0)),
            status: self.COMPLETED,
            created: now()
        });
        //Transfer to taker Price Asset - FeeTaker

        require(escrow.value > 0, "Insufficient balance");

        send(SendParameters{
            to: sender(),
            bounce: true,   
            value: escrow.value - _amountFeeTaker,
            mode: SendIgnoreErrors + SendRemainingValue
        });

        dump(self.feesAvailableNativeCoin);
    }

    receive (msg: RefundMakerNativeCoin) {
        self.onlyOwner();
        let escrow: EscrowData = self.escrows.get(msg._orderId)!!;
        require(
            escrow.status == self.FIATCOIN_TRANSFERED || escrow.status == self.CRYPTOS_IN_CUSTODY,
            "Refund not approved"
        );

        let _amountFeeMaker: Int = self.getAmountFeeMaker(msg._orderId);

        require(self.feesAvailableNativeCoin > _amountFeeMaker + self.MinTonForStorage, "Contract amount must not be less than MinTonForStorage amount");

        // write as complete, in case transfer fails
        self.escrows.set(msg._orderId, EscrowData{
            maker: sender(),
            taker: escrow.taker,
            maker_premium: escrow.maker_premium,
            taker_premium: escrow.taker_premium,
            value: escrow.value,
            takerFee: self.feeTaker,
            makerFee: self.feeMaker,
            status: self.REFUND,
            created: now()
        });

        self.feesAvailableNativeCoin -= _amountFeeMaker; 

        send(SendParameters{
            to: sender(),
            bounce: true,   
            value: escrow.value + _amountFeeMaker,
            mode: SendIgnoreErrors + SendRemainingValue
        });
    }

    receive (msg: CancelMakerNative) {
        self.onlyMaker(msg.orderId);
        let escrow: EscrowData = self.escrows.get(msg.orderId)!!;
        require(
            escrow.status == self.CRYPTOS_IN_CUSTODY,
            "Status must be CRYPTOS_IN_CUSTODY"
        );

        let _timeDiff: Int = now() - escrow.created;
        let timeProcess: Int = self.timeProcess();

        require(_timeDiff > timeProcess, "Time is still running out.");
        let _amountFeeMaker: Int = self.getAmountFeeMaker(msg.orderId);
        require(self.feesAvailableNativeCoin > _amountFeeMaker + self.MinTonForStorage, "Contract amount must not be less than MinTonForStorage amount");

        // write as complete, in case transfer fails
        self.escrows.set(msg.orderId, EscrowData{
            maker: sender(),
            taker: escrow.taker,
            maker_premium: escrow.maker_premium,
            taker_premium: escrow.taker_premium,
            value: escrow.value,
            takerFee: self.feeTaker,
            makerFee: self.feeMaker,
            status: self.CANCEL_MAKER,
            created: now()
        });

        self.feesAvailableNativeCoin -= _amountFeeMaker; 


        send(SendParameters{
            to: sender(),
            bounce: true,   
            value: escrow.value + _amountFeeMaker,
            mode: SendIgnoreErrors + SendRemainingValue
        });
    }

    receive (msg: CancelTakerNative) {
        self.onlyTaker(msg.orderId);
        let escrow: EscrowData = self.escrows.get(msg.orderId)!!;
        require(
            escrow.status == self.CRYPTOS_IN_CUSTODY,
            "Status must be CRYPTOS_IN_CUSTODY"
        );

        let _timeDiff: Int = now() - escrow.created;
        let timeProcess: Int = self.timeProcess();

        require(_timeDiff > timeProcess, "Time is still running out.");

        // write as complete, in case transfer fails
        self.escrows.set(msg.orderId, EscrowData{
            maker: sender(),
            taker: escrow.taker,
            maker_premium: escrow.maker_premium,
            taker_premium: escrow.taker_premium,
            value: escrow.value,
            takerFee: self.feeTaker,
            makerFee: self.feeMaker,
            status: self.CANCEL_TAKER,
            created: now()
        });

        let _amountFeeTaker: Int = self.getAmountFeeTaker(msg.orderId);
        self.feesAvailableNativeCoin -= _amountFeeTaker; 


        send(SendParameters{
            to: sender(),
            bounce: true,   
            value: escrow.value + _amountFeeTaker,
            mode: SendIgnoreErrors + SendRemainingValue
        });
    }

    receive (msg: WithdrawFeesNative) {
        self.onlyOwner();
        require(self.feesAvailableNativeCoin>0, "Insufficient balance");

        let _amount = self.feesAvailableNativeCoin - self.MinTonForStorage;

        self.feesAvailableNativeCoin -= _amount;

        send(SendParameters{
            to: sender(),
            bounce: true,
            value: _amount,
            mode: SendIgnoreErrors + SendRemainingValue
        });
    }


    receive("withdraw all"){
        self.onlyOwner();
        send(SendParameters{
            to: sender(),
            bounce: true,
            value: 0,
            mode: SendRemainingBalance + SendIgnoreErrors
        });
    }

    receive("withdraw safe"){
        self.onlyOwner();
        send(SendParameters{
            to: sender(),
            bounce: true,
            value: myBalance() - context().value - self.MinTonForStorage,
            mode: SendIgnoreErrors + SendRemainingValue
        });
    }

    // withdraw specific amount 
    receive(msg: Withdraw){
        self.onlyOwner();
        let amount: Int = min(msg.amount, myBalance() - context().value - self.MinTonForStorage);
        require(amount>0, "Insufficient balance");
        send(SendParameters{
            to: sender(),
            bounce: true,
            value: amount,
            mode: SendIgnoreErrors + SendRemainingValue
        });
    }

    // ================== Begin Internal functions ==================

    fun onlyOwner(){
        require(sender() == self.owner, "only owner is allowed to withdraw");
    }

    fun onlyMaker(orderId: Int){
        let escrow: EscrowData = self.escrows.get(orderId)!!;
        require(sender() == escrow.maker, "Not Maker");
    }

    fun onlyTaker(orderId: Int){
        let escrow: EscrowData = self.escrows.get(orderId)!!;

        require(sender() == escrow.taker, "Not Taker");
    }

      fun getAmountFeeTaker(_orderId: Int): Int {
        //get decimal of stable
        let _amountFeeTaker: Int = 0;

        let escrow: EscrowData = self.escrows.get(_orderId)!!;

        // Validations Premium
        if (!escrow.taker_premium) {
            //get amountFeeTaker
            _amountFeeTaker = escrow.value * escrow.takerFee / 10000;
        }

        return _amountFeeTaker;
    }

    // ================== Begin Getter functions ==================

    get fun balance(): Int{
        return myBalance();
    }

    get fun makerFee(): Int {
        return self.feeMaker;
    }

    fun getAmountFeeMaker(_orderId: Int): Int {
        //get decimal of stable
        let _amountFeeMaker: Int = 0;

        let escrow: EscrowData = self.escrows.get(_orderId)!!;

        // Validations Premium
        if (!escrow.maker_premium) {
            //get amountFeeTaker
            _amountFeeMaker = escrow.value * escrow.makerFee / 10000;
        }

        return _amountFeeMaker;
    }

    get fun takerFee(): Int {
        return self.feeTaker;
    }

    get fun timeProcess(): Int {
        return self.timeProcess;
    }

    get fun feeAvailable(): Int {
        self.onlyOwner();
        return self.timeProcess;
    }

    get fun escrowOrder(id: Int): EscrowData? {
        // let escrow: EscrowData = self.escrows.get(1)!!;
        return self.escrows.get(id);
    }

    get fun allEscrowOrder(): map<Int, EscrowData> {
        // let escrow: EscrowData = self.escrows.get(1)!!;
        return self.escrows;
    }

    get fun owner(): Address {
        return self.owner;
    }
}