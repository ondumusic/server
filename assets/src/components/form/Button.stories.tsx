import type { Meta, StoryObj } from "@storybook/react-vite";
import { Button } from "./Button";

const meta = {
  title: "Forms/Button",
  component: Button,
} satisfies Meta<typeof Button>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Primary: Story = {
  args: {
    type: "button",
    disabled: false,
    children: "Button Text",
  },
};

export const Disabled: Story = {
  args: {
    type: "button",
    disabled: true,
    children: "Button Text",
  },
};

export const Secondary: Story = {
  args: {
    type: "button",
    style: "secondary",
    disabled: false,
    children: "Button Text",
  },
};

export const SecondaryDisabled: Story = {
  args: {
    type: "button",
    style: "secondary",
    disabled: true,
    children: "Button Text",
  },
};

export const Link: Story = {
  args: {
    type: "button",
    link: true,
    disabled: false,
    children: "Button Text",
  },
};

export const LinkDisabled: Story = {
  args: {
    type: "button",
    link: true,
    disabled: true,
    children: "Button Text",
  },
};

export const SecondaryLink: Story = {
  args: {
    type: "button",
    link: true,
    style: "secondary",
    disabled: false,
    children: "Button Text",
  },
};

export const SecondaryLinkDisabled: Story = {
  args: {
    type: "button",
    link: true,
    style: "secondary",
    disabled: true,
    children: "Button Text",
  },
};

export const CustomChild: Story = {
  args: {
    type: "button",
    disabled: false,
    children: (
      <>
        <em>Hello</em> <strong>World</strong>
      </>
    ),
  },
};
