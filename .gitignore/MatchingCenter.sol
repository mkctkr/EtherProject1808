pragma solidity ^0.4.24;

contract MatchingCenter{ 
    struct Donator {
        string  Name;
        string  BloodType;
        address Addr;
        address patientAddress;
    }

    struct Patient {
        string  Name;
        string  BloodType;
        address Addr;
    }

    struct MatchResult{
        address patientAddress;
        address donatorAddress;
    }

    address owner;
    address[] public patientList;
    address[] public donatorList;
    MatchResult[] public matchedList;

    mapping ( address => Patient )     patients;
    mapping ( address => Donator )     donators;

    function Strcmp (string a, string b) view returns (bool){
       return keccak256(a) == keccak256(b);
    }

    function registerDonator(string _name, string _bloodtype, address _patientAddr) public requiredState(STATE.REGISTER_OPENED) {
        donators[msg.sender].Name = _name;
        donators[msg.sender].BloodType = _bloodtype;
        donators[msg.sender].patientAddress = _patientAddr;
        donatorList.push( msg.sender );
    } 

    function registerPatient(string _name, string _bloodtype) public  requiredState(STATE.REGISTER_OPENED) {
        patients[msg.sender].Name = _name;
        patients[msg.sender].BloodType = _bloodtype;
        patientList.push( msg.sender );
    }
    
    function getPatient(address _addr) public returns (string _name, string _bloodtype) {
        return (patients[_addr].Name, patients[_addr].BloodType);
    }

    function getDonator(address _addr) public returns (string _name, string _bloodtype, address _patientaddr) {
        return (donators[_addr].Name, donators[_addr].BloodType, donators[_addr].patientAddress);
    }

    // two step 
    // 1. Donator -> Patient 
    // 2. Patient -> Donator
    function DeterMatching() public onlyGovernor {
        // first step : Donator -> Patient 
        for(uint i=0; i<donatorList.length; i++)
        {
            for(uint j=0; j<patientList.length; j++)
            {
                if(donators[donatorList[i]].patientAddress == patientList[j])
                {
                    regMatchset(patientList[j], donatorList[i]);
                    break;
                }
            }
        }

        // second step : Patient -> Donator
        for(i=0; i<patientList.length; i++)
        {
            for(uint c=1; c<=2; c++)
            {
                for(j=0; j<donatorList.length; j++)
                {
                   if( donableChk(patientList[i], donatorList[j]) == c )
                    {
                        regMatchset(patientList[i], donatorList[j]);
                        break;
                    }
                }
            }
        }
        
        state = STATE.ANNOUNCED;
    }

    /*
    function getMatchedList() public return (MatchResult[]) {
        return matchedList[];
    }
    */

    function regMatchset (address pat, address don) private onlyGovernor {
        MatchResult storage matchresult;

        matchresult.patientAddress = pat;
        matchresult.donatorAddress = don;

        matchedList.push( matchresult );
    }

    function donableChk(address pat, address don) private view returns (uint){
        string patBloodTp = patients[pat].BloodType;
        string donBloodTp = donators[don].BloodType;
        uint prior = 0;

        prior = ( Strcmp(patBloodTp, donBloodTp) ) ? 1 : ( !Strcmp(patBloodTp, donBloodTp) && Strcmp(donBloodTp, "O") ? 2 : 0 );

        return prior;

        /*
        if(patBloodTp == donBloodTp)
        {
            prior = 1;
        }

        else if(patBloodTp != donBloodTp && donBloodTp == "O")
        {
            prior = 2;
        }
        else
        {
            prior = 0;
        }

        return prior;
        */
    }

    constructor() public {
        state = STATE.CREATED;
        governor = msg.sender;
    }

    // ======================================================================================
    // Donator-Patient matching states
    // ======================================================================================
    enum STATE { CREATED, REGISTER_OPENED, REGISTER_CLOSED, ANNOUNCED }
    STATE public state;
    address public governor;

    modifier requiredState(STATE st) { require(st == state, 'Invalid State'); _; }
    modifier onlyGovernor() { require(msg.sender == governor, 'msg.sender is not Governor'); _; }

    function openRegistration() public onlyGovernor requiredState(STATE.CREATED) {
        state = STATE.REGISTER_OPENED;
    }

    function closeRegistartion() public onlyGovernor requiredState(STATE.REGISTER_OPENED) {
        state = STATE.REGISTER_CLOSED;
        
        DeterMatching();
    }
    // ======================================================================================


    // ======================================================================================
    // Browsing match result APIs
    // ======================================================================================
    // return: (match result, Partner Name, Partner BloodType)
    function getMatchingResult(bool isDonator) public view requiredState(STATE.ANNOUNCED) returns (bool, string, string) {
        if (isDonator)
        {
            for (uint i=0; i<matchedList.length; i++)
            {
                if(msg.sender == matchedList[i].donatorAddress)
                {
                    Donator storage d = donators[matchedList[i].donatorAddress];
                    return (true, d.Name, d.BloodType);
                }
            }
        }
        else 
        {
            for (i=0; i<matchedList.length; i++)
            {
                if(msg.sender == matchedList[i].patientAddress)
                {
                    Patient storage p = patients[matchedList[i].patientAddress];
                    return (true, p.Name, p.BloodType);
                }
            }
        }

        return (false, "", "");
    }

    function getNumberOfMatchedPair() public view requiredState(STATE.ANNOUNCED) onlyGovernor returns (uint)
    {
        return matchedList.length;
    }

    // return: (Donator name, Donator BloodType, Patient name, Patient BloodType)
    function browseMatchedList(uint index) public view requiredState(STATE.ANNOUNCED) onlyGovernor returns (string, string, string, string)
    {
        if(index >= matchedList.length)
        {
            revert("Index out of bound");
        }

        Donator storage d = donators[matchedList[index].donatorAddress];
        Patient storage p = patients[matchedList[index].patientAddress];

        return (d.Name, d.BloodType, p.Name, p.BloodType);
    }
    // ======================================================================================
}
