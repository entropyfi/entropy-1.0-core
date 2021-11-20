// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

interface AggregatorV3Interface {
	// function decimals() external view returns (uint8);
	// function description() external view returns (string memory);
	// function version() external view returns (uint256);

	// getRoundData and latestRoundData should both raise "No data present"
	// if they do not have data to report, instead of returning unset values
	// which could be misinterpreted as actual reported values.
	// function getRoundData(uint80 _roundId)
	// 	external
	// 	view
	// 	returns (
	// 		uint80 roundId,
	// 		int256 answer,
	// 		uint256 startedAt,
	// 		uint256 updatedAt,
	// 		uint80 answeredInRound
	// 	);

	function latestRoundData()
		external
		view
		returns (
			uint80 roundId,
			int256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		);
}

contract Aggregator is AggregatorV3Interface {
	uint80 public roundId;
	int256 public answer;
	uint256 public startedAt;
	uint256 public updatedAt;
	uint80 public answeredInRound;

	function setRoundData(
		uint80 roundId_,
		int256 answer_,
		uint256 startedAt_,
		uint256 updatedAt_,
		uint80 answeredInRound_
	) external {
		roundId = roundId_;
		answer = answer_;
		startedAt = startedAt_;
		updatedAt = updatedAt_;
		answeredInRound = answeredInRound_;
	}

	// function getRoundData(uint80 _roundId)
	// 	external
	// 	view
	//   override
	// 	returns (
	// 		uint80 roundId_,
	// 		int256 answer_,
	// 		uint256 startedAt_,
	// 		uint256 updatedAt_,
	// 		uint80 answeredInRound_
	// 	)
	// {
	// 	roundId_ = roundId;
	// 	answer_ = answer;
	// 	startedAt_ = startedAt;
	// 	updatedAt_ = updatedAt;
	// 	answeredInRound_ = answeredInRound;
	// }

	function latestRoundData()
		external
		view
		override
		returns (
			uint80 roundId_,
			int256 answer_,
			uint256 startedAt_,
			uint256 updatedAt_,
			uint80 answeredInRound_
		)
	{
		roundId_ = roundId;
		answer_ = answer;
		startedAt_ = startedAt;
		updatedAt_ = updatedAt;
		answeredInRound_ = answeredInRound;
	}
}
