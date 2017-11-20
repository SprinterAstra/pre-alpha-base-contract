pragma solidity ^0.4.11;

import '../base/Base.sol';
import '../offer/HolderAdCoins.sol';
import '../offer/Offer.sol';
import '../offer/OfferContract.sol';
import '../Questionnaire.sol';
import '../search/Search.sol';
import '../search/SearchContract.sol';
import '../search/SearchRequest.sol';
import '../helpers/Bytes32Utils.sol';
import 'zeppelin-solidity/contracts/math/Math.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';


contract BaseContract is Base {
    using Bytes32Utils for bytes32;
    using SafeMath for uint256;

    function BaseContract() {
    }

    function setTokensContract(address tokenContractAddress) onlySameOwner whenNotPaused external {
        tokenContract = BasicToken(tokenContractAddress);

        for (uint i = 0; i < offers.length; i++){
            Offer offer = Offer(offers[i]);
            if (address(offer.tokenContract) != address(tokenContractAddress)) {
                offer.setTokensContract(tokenContract);
            }
        }
    }

    function setSearchContract(address searchContractAddress) onlySameOwner whenNotPaused external {
        require(Search(searchContractAddress).owner() == owner);

        searchContract = Search(searchContractAddress);
    }

    function getOffers() onlySameOwner constant external returns(address[]) {
        return offers;
    }

    function getOffer(uint index) onlySameOwner constant external returns(address) {
        require(index < offers.length && index >= 0);

        return offers[index];
    }

    function getOffersCount() onlySameOwner constant external returns(uint) {
        return offers.length;
    }

    function getAdvertiserOffers() public constant returns(address[]) {
        return mapAdvertiserOffers[msg.sender];
    }

    function getQuestionnaires() external constant returns (address[]) {
        return questionnaires;
    }

    function transferClientRewards(address _offer, address searchRequest) whenNotPaused public {
        require(searchRequest != address(0x0));
        require(_offer != address(0x0));

        SearchRequest request = SearchRequest(searchRequest);
        require(msg.sender == request.owner());

        Offer offer = Offer(_offer);

        uint256 reward = request.getRewardByOffer(_offer);

        require(reward > 0);
        require(offer.holderCoins().getBalance() >= reward);

        request.setRewardByOffer(_offer, 0x0);

        uint8 showedCount = request.getNumberOfViews(_offer);
        if (showedCount < searchContract.MAX_COUNT_SHOWED_AD()) {
            request.incrementNumberViewedOffer(_offer);
        }

        offer.payReward(msg.sender, reward);

        ClientReward(_offer, msg.sender,  reward);
    }

    function createOffer(address questionnaire) whenNotPaused public {
        require(questionnaire != address(0x0));
        require(Questionnaire(questionnaire).getStepCount() > 0);

        Offer offer = new OfferContract(
            msg.sender,
            questionnaire,
            address(tokenContract)
        );

        mapAdvertiserOffers[msg.sender].push(address(offer));

        offers.push(address(offer));

        searchContract.addOffer(address(offer));

        CreateOffer(msg.sender, address(offer));
    }

    function addQuestionnaire(address questionnaire) onlySameOwner whenNotPaused external {
        require(questionnaire != address(0x0));

        for (uint i = 0; i < questionnaires.length; i++) {
            require(questionnaires[i] != questionnaire);
        }

        questionnaires.push(questionnaire);
    }

    function cloneContract(address newBaseContract) onlyOwner public {
        require(newBaseContract != address(0x0));
        require(Base(newBaseContract).owner() == owner);

        Base baseContract = Base(newBaseContract);
        baseContract.setQuestionnaires(questionnaires);

        for(uint i = 0; i < offers.length; i++) {
            Offer offer = Offer(offers[i]);
            offer.transferOwnership(address(baseContract));
        }

        baseContract.setOffers(offers);

        searchContract.setBaseContract(address(baseContract));

        baseContract.setTokensContract(address(tokenContract));
        baseContract.setSearchContract(address(searchContract));
    }

    function setQuestionnaires(address[] questionnaireContracts) onlySameOwner whenNotPaused public {
        questionnaires = questionnaireContracts;
    }

    function setOffers(address[] offersContracts) onlySameOwner whenNotPaused public {
        offers = offersContracts;

        for(uint i = 0; i < offers.length; i++) {
            Offer offer = Offer(offers[i]);
            mapAdvertiserOffers[offer.getAdvertiser()].push(address(offer));
        }
    }

}