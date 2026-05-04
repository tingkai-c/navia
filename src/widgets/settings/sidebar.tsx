import { Assets } from "assets";
import { BackButton } from "components/BackButton";
import { SelectableButton } from "components/SelectableButton";
import { SETTINGS_SECTIONS, type SettingsSection } from "lib/settingsSections";
import { type ImageSourcePropType, View } from "react-native";
import { useStore } from "store";
import { Widget } from "stores/ui.store";

const SETTINGS_SECTION_CONTENT: Record<
	SettingsSection,
	{ icon: ImageSourcePropType; title: string; className?: string }
> = {
	GENERAL: { icon: Assets.macosSettings, title: "General" },
	TRANSLATE: { icon: Assets.translate, title: "Translation" },
	ITEMS: {
		icon: Assets.shortcuts,
		title: "Items",
		className: "items-center ",
	},
	ABOUT: {
		icon: Assets.smallLogo,
		title: "About",
		className: "items-center ",
	},
	SCRIPTS: { icon: Assets.terminal, title: "Scripts" },
	CALENDARS: { icon: Assets.Calendar, title: "Calendars" },
};

export const Sidebar = ({
	selected,
	setSelected,
}: {
	selected: SettingsSection;
	setSelected: (selected: SettingsSection) => unknown;
}) => {
	const store = useStore();

	return (
		<View className="p-3 w-56">
			<BackButton
				onPress={() => store.ui.focusWidget(Widget.SEARCH)}
				className="mb-2"
			/>
			{SETTINGS_SECTIONS.map((section) => {
				const item = SETTINGS_SECTION_CONTENT[section];

				return (
					<SelectableButton
						key={section}
						icon={item.icon}
						className={item.className}
						selected={selected === section}
						onPress={() => setSelected(section)}
						title={item.title}
					/>
				);
			})}
		</View>
	);
};
