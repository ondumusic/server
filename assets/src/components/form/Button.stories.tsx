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
