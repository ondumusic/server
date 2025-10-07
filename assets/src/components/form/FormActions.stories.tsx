import type { Meta, StoryObj } from "@storybook/react-vite";
import { Button } from "./Button";
import { FormActions } from "./FormActions";

const meta = {
  title: "Forms/FormActions",
  component: FormActions,
} satisfies Meta<typeof FormActions>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Buttons: Story = {
  args: {
    children: (
      <>
        <Button type="submit">Save</Button>
        <Button type="button" link>
          Cancel
        </Button>
      </>
    ),
  },
};

export const CustomClassName: Story = {
  args: {
    className: "gap-0",
    children: (
      <>
        <Button type="submit">Save</Button>
        <Button type="button" link>
          Cancel
        </Button>
      </>
    ),
  },
};
