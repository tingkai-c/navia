const FULLWIDTH_ASCII_OFFSET = 0xfee0;
const IDEOGRAPHIC_SPACE = /\u3000/g;

export function normalizeFullwidthAscii(input: string) {
	return input
		.replace(IDEOGRAPHIC_SPACE, " ")
		.replace(/[\uff01-\uff5e]/g, (char) =>
			String.fromCharCode(char.charCodeAt(0) - FULLWIDTH_ASCII_OFFSET),
		);
}

export function normalizeQueryForMatching(input: string) {
	return normalizeFullwidthAscii(input);
}

export function tokenizeQueryText(text: string) {
	return normalizeQueryForMatching(text)
		.toLowerCase()
		.split(/[\s.-]+/);
}
