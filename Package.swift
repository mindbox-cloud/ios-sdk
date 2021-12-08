// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Mindbox",
	platforms: [.iOS(.v10)],
	products: [
		.library(
			name: "Mindbox",
			targets: ["Mindbox"]),
		.library(
			name: "MindboxNotifications",
			targets: ["MindboxNotifications"])
	],
	dependencies: [],
	targets: [
		.target(
			name: "Mindbox",
			dependencies: [],
			path: "Mindbox",
			resources: [
				.copy("Model/Bodies/MobileApplication")
			]),
		.target(
			name: "MindboxNotifications",
			dependencies: [],
			path: "MindboxNotifications",
			resources: []),
		.testTarget(
			name: "MindboxTests",
			dependencies: ["Mindbox"],
			path: "MindboxTests",
			resources: [
				.copy("Supporting Files"),
				.copy("Mock/SuccessResponse.json"),
				.copy("EventRepository/TestEventConfig.plist")
			]),
		.testTarget(
			name: "MindboxNotificationsTests",
			dependencies: ["MindboxNotifications"],
			path: "MindboxNotificationsTests",
			resources: []),
	]
)
