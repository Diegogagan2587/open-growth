# Card Component Usage

The Card component system is a fully composable set of ViewComponents matching shadcn's design. Here are common usage patterns:

## Basic Card

```erb
<%= render Ui::CardComponent.new do %>
  <div>Simple card content</div>
<% end %>
```

## Card with Header, Title & Description

```erb
<%= render Ui::CardComponent.new do %>
  <%= render Ui::CardHeaderComponent.new do %>
    <%= render Ui::CardTitleComponent.new do %>
      Card Title
    <% end %>
    <%= render Ui::CardDescriptionComponent.new do %>
      Additional description text goes here
    <% end %>
  <% end %>
<% end %>
```

## Card with Content & Footer

```erb
<%= render Ui::CardComponent.new do %>
  <%= render Ui::CardHeaderComponent.new do %>
    <%= render Ui::CardTitleComponent.new do %>
      Create Account
    <% end %>
  <% end %>
  
  <%= render Ui::CardContentComponent.new do %>
    <!-- Your form or content here -->
  <% end %>
  
  <%= render Ui::CardFooterComponent.new do %>
    <%= render Ui::ButtonComponent.new(variant: :default) do %>
      Submit
    <% end %>
  <% end %>
<% end %>
```

## Card with Action

```erb
<%= render Ui::CardComponent.new do %>
  <%= render Ui::CardHeaderComponent.new do %>
    <%= render Ui::CardTitleComponent.new do %>
      Account Settings
    <% end %>
    <%= render Ui::CardActionComponent.new do %>
      <%= render Ui::ButtonComponent.new(variant: :ghost, size: :icon) do %>
        <!-- Your icon here -->
      <% end %>
    <% end %>
  <% end %>
  
  <%= render Ui::CardContentComponent.new do %>
    <!-- Content -->
  <% end %>
<% end %>
```

## Small Card Variant

```erb
<%= render Ui::CardComponent.new(size: :sm) do %>
  <div>Compact card with smaller padding</div>
<% end %>
```

## Custom Styling

All components accept a `css_class` parameter for custom Tailwind classes:

```erb
<%= render Ui::CardComponent.new(css_class: "shadow-xl border-2") do %>
  Custom styled card
<% end %>

<%= render Ui::CardHeaderComponent.new(css_class: "bg-slate-100") do %>
  Header with background
<% end %>
```

## Complete Example

```erb
<%= render Ui::CardComponent.new do %>
  <%= render Ui::CardHeaderComponent.new do %>
    <%= render Ui::CardTitleComponent.new do %>
      Budget Period
    <% end %>
    <%= render Ui::CardDescriptionComponent.new do %>
      January 2024 Summary
    <% end %>
    <%= render Ui::CardActionComponent.new do %>
      <%= render Ui::ButtonComponent.new(variant: :outline, size: :sm) do %>
        Edit
      <% end %>
    <% end %>
  <% end %>

  <%= render Ui::CardContentComponent.new do %>
    <div class="space-y-2">
      <p>Total Income: $5,000</p>
      <p>Total Expenses: $3,200</p>
      <p>Balance: $1,800</p>
    </div>
  <% end %>

  <%= render Ui::CardFooterComponent.new do %>
    <%= render Ui::ButtonComponent.new(variant: :secondary) do %>
      View Details
    <% end %>
  <% end %>
<% end %>
```

## Available Props

### CardComponent
- `size: "default" | "sm"` - Padding size (default: "default")
- `css_class: string` - Additional Tailwind classes

### All Sub-Components
- `css_class: string` - Additional Tailwind classes

## Size Variants

| Size | Padding |
|------|---------|
| default | p-6 |
| sm | p-4 |
