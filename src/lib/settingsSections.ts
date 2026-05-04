export const SETTINGS_SECTIONS = [
	"GENERAL",
	"TRANSLATE",
	"ITEMS",
	"ABOUT",
	"SCRIPTS",
	"CALENDARS",
] as const;

export type SettingsSection = (typeof SETTINGS_SECTIONS)[number];

export const DEFAULT_SETTINGS_SECTION: SettingsSection = SETTINGS_SECTIONS[0];

export function getAdjacentSettingsSection(
	currentSection: SettingsSection,
	direction: "previous" | "next",
): SettingsSection {
	const currentIndex = SETTINGS_SECTIONS.indexOf(currentSection);
	const nextIndex =
		direction === "previous"
			? Math.max(0, currentIndex - 1)
			: Math.min(SETTINGS_SECTIONS.length - 1, currentIndex + 1);

	return SETTINGS_SECTIONS[nextIndex];
}
