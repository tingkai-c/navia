import {
	normalizeFullwidthAscii,
	normalizeQueryForMatching,
	tokenizeQueryText,
} from "./queryNormalization";

describe("queryNormalization", () => {
	it("folds fullwidth ASCII letters to normal ASCII", () => {
		expect(normalizeQueryForMatching("ｃａｌ")).toBe("cal");
		expect(normalizeQueryForMatching("ＡＢＣｘｙｚ")).toBe("ABCxyz");
	});

	it("folds fullwidth digits, punctuation, and spaces", () => {
		expect(normalizeFullwidthAscii("１２３．４５")).toBe("123.45");
		expect(normalizeFullwidthAscii("foo　bar")).toBe("foo bar");
	});

	it("does not transliterate non-fullwidth text", () => {
		expect(normalizeQueryForMatching("中文かな한글")).toBe("中文かな한글");
	});

	it("tokenizes after folding fullwidth ASCII", () => {
		expect(tokenizeQueryText("Ｆｏｏ．Ｂａｒ-baz")).toEqual([
			"foo",
			"bar",
			"baz",
		]);
	});
});
