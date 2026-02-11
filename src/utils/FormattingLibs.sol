// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.26;

import {Strings} from "@openzeppelin-v5/contracts/utils/Strings.sol";

using Strings for uint256;

/// @notice Shared formatter for scaled integer amounts (e.g. 18-decimal wei to "1.5").
function formatScaledAmount(uint256 amount, uint8 exponent, uint8 maxDecimals) pure returns (string memory) {
    if (exponent > maxDecimals) {
        uint256 factor = 10 ** (exponent - maxDecimals);
        uint256 half = factor / 2;
        // avoid overflow for very large amounts
        amount = amount <= type(uint256).max - half ? (amount + half) / factor : amount / factor;
    }
    uint256 intPart = amount / 10 ** maxDecimals;
    uint256 fracPart = amount % 10 ** maxDecimals;
    string memory intString = intPart.toString();
    if (fracPart == 0) return intString;
    string memory fracString = fracPart.toString();
    while (bytes(fracString).length < maxDecimals) {
        fracString = string.concat("0", fracString);
    }
    return string.concat(intString, ".", fracString);
}

library FlowRateFormatter {
    using Strings for uint256;

    enum Period {
        SECOND,
        MINUTE,
        HOUR,
        DAY,
        WEEK,
        MONTH,
        YEAR
    }

    error InvalidPeriod();

    function getSecondsInPeriod(Period period) private pure returns (uint256) {
        if (period == Period.SECOND) return 1;
        if (period == Period.MINUTE) return 60;
        if (period == Period.HOUR) return 3600;
        if (period == Period.DAY) return 86400;
        if (period == Period.WEEK) return 604800;
        if (period == Period.MONTH) return 2628000;
        if (period == Period.YEAR) return 31536000;
        revert InvalidPeriod();
    }

    function toDailyFlowRateString(int96 flowRate) internal pure returns (string memory) {
        return toFlowRateString(flowRate, Period.DAY, 5);
    }

    function toFlowRateString(int96 flowRate, Period period, uint8 maxDecimals) internal pure returns (string memory) {
        int256 absFlowRate = (flowRate < 0) ? -flowRate : flowRate;
        uint256 tokensPerPeriod = uint256(absFlowRate) * getSecondsInPeriod(period);
        string memory frAbs = formatScaledAmount(tokensPerPeriod, 18, maxDecimals);
        return (flowRate < 0) ? string.concat("-", frAbs) : frAbs;
    }
}

library AmountFormatter {
    /// @notice Format a raw token amount (18 decimals) for display.
    function formatTokenAmount(uint256 amount, uint8 maxDecimals) internal pure returns (string memory) {
        return formatScaledAmount(amount, 18, maxDecimals);
    }
}

library RelativeTimeFormatter {
    using Strings for uint256;

    /// @notice Returns a human-readable diff from now to the given timestamp, e.g. "in 5 days and 3 hours", or "the past" if not in the future.
    /// @param futureTimestamp Unix timestamp (if in the past, returns "the past").
    function formatFromNow(uint256 futureTimestamp) internal view returns (string memory) {
        if (futureTimestamp <= block.timestamp) return "the past";
        uint256 delta = futureTimestamp - block.timestamp;

        uint256 days_ = delta / 86400;
        uint256 rem = delta % 86400;
        uint256 hours_ = rem / 3600;
        rem = rem % 3600;
        uint256 minutes_ = rem / 60;
        uint256 seconds_ = rem % 60;

        if (days_ > 0) {
            string memory d = _unit(days_, "day", "days");
            if (hours_ > 0) return string.concat("in ", d, " and ", _unit(hours_, "hour", "hours"));
            return string.concat("in ", d);
        }
        if (hours_ > 0) {
            string memory h = _unit(hours_, "hour", "hours");
            if (minutes_ > 0) return string.concat("in ", h, " and ", _unit(minutes_, "minute", "minutes"));
            return string.concat("in ", h);
        }
        if (minutes_ > 0) {
            string memory m = _unit(minutes_, "minute", "minutes");
            if (seconds_ > 0) return string.concat("in ", m, " and ", _unit(seconds_, "second", "seconds"));
            return string.concat("in ", m);
        }
        return string.concat("in ", _unit(seconds_, "second", "seconds"));
    }

    function _unit(uint256 n, string memory singular, string memory plural) private pure returns (string memory) {
        return string.concat(n.toString(), " ", n == 1 ? singular : plural);
    }
}
