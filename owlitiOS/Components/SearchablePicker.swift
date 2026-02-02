//
//  SearchablePicker.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 16/12/2025.
//

import SwiftUI

struct SearchablePicker: View {
    let title: String
    let placeholder: String
    @Binding var selection: String
    let options: [String]
    var allowCreate: Bool = true
    var displayIcon: (String) -> AnyView = { _ in AnyView(EmptyView()) } // Optional icon provider
    var onSelect: ((String) -> Void)? = nil
    var onCreate: ((String) -> Void)? = nil
    var fontSize: CGFloat = 14 // Default font size

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var isPresentingSheet = false
    
    // Adaptive Colors
    private var isDarkMode: Bool { colorScheme == .dark }
    private var sheetBg: Color { isDarkMode ? Color.black : Color(hex: "F2F2F7") }
    private var cardBg: Color { isDarkMode ? Color(hex: "1C1C1E") : Color.white }
    private var primaryText: Color { isDarkMode ? Color.white : Color.black }
    private var secondaryText: Color { isDarkMode ? Color.gray : Color.gray }
    private var accentGreen: Color { Color(hex: "27A565") }

    var filteredOptions: [String] {
        if searchText.isEmpty {
            return options
        } else {
            return options.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var showCreateOption: Bool {
        allowCreate && !searchText.isEmpty && !options.contains { $0.localizedCaseInsensitiveCompare(searchText) == .orderedSame }
    }

    var body: some View {
        Button(action: {
            isPresentingSheet = true
        }) {
            HStack {
                displayIcon(selection).font(.system(size: fontSize))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(selection.isEmpty ? placeholder : selection)
                        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(selection.isEmpty ? primaryText.opacity(0.3) : (isDarkMode ? primaryText.opacity(0.6) : primaryText.opacity(0.9)))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(primaryText.opacity(0.5))
            }
            .contentShape(Rectangle()) // Make clickable area better
        }
        .sheet(isPresented: $isPresentingSheet) {
            NavigationView {
                ZStack {
                    sheetBg.ignoresSafeArea()
                    
                    List {
                        if showCreateOption {
                            Button(action: {
                                let newValue = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                selection = newValue
                                onCreate?(newValue)
                                onSelect?(newValue)
                                isPresentingSheet = false
                                searchText = ""
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(accentGreen)
                                    Text("Create \"\(searchText)\"")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .tracking(0.5)
                                        .foregroundColor(primaryText.opacity(0.8))
                                }
                            }
                            .listRowBackground(cardBg)
                        }
                        
                        ForEach(filteredOptions, id: \.self) { option in
                            Button(action: {
                                selection = option
                                onSelect?(option)
                                isPresentingSheet = false
                            }) {
                                HStack {
                                    displayIcon(option)
                                        .foregroundColor(primaryText.opacity(0.7))
                                        .frame(width: 24)
                                    
                                    Text(option)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .tracking(0.5)
                                        .foregroundColor(primaryText.opacity(0.8))
                                    
                                    if selection == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(accentGreen)
                                    }
                                }
                            }
                            .listRowBackground(cardBg)
                        }
                        
                        if filteredOptions.isEmpty && !showCreateOption {
                           Text("No options found")
                               .foregroundColor(secondaryText)
                               .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.grouped) // Better for adaptive
                    .scrollContentBackground(.hidden) 
                    .background(sheetBg)
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(title.lowercased())...")
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresentingSheet = false
                        }
                        .foregroundColor(primaryText)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            // Removed .preferredColorScheme(.dark) to fix the bug
        }
    }
}
